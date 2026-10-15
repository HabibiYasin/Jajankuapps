'use strict';

const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onMessagePublished} = require('firebase-functions/v2/pubsub');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {userStatus, voucherQuote} = require('./catalog');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineString} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const {GoogleAuth} = require('google-auth-library');
const {PRODUCT_ID, hash, everPremium, readSubscription, assertOwner, chooseEntitlement, rejectIntro, purchaseAccountId} = require('./premium');

initializeApp();
const db = getFirestore();
const region = 'asia-southeast2';
// Explicit per-project configuration prevents a dev server accepting prod purchases.
const packageName = defineString('PLAY_PACKAGE_NAME');
const playAuth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/androidpublisher']});
const accountId = uid => hash(`${process.env.GCLOUD_PROJECT}:${uid}`);
const accountRef = uid => db.collection('billingAccounts').doc(accountId(uid));
const purchaseRef = token => db.collection('playPurchases').doc(hash(token));

async function playRequest(path, method = 'GET', data) {
  const client = await playAuth.getClient();
  return (await client.request({
    url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName.value())}/${path}`,
    method, data,
  })).data;
}
const fetchPurchase = token => playRequest(`purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`);

function requireUser(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Masuk terlebih dahulu.');
  const token = request.auth.token;
  if (token.firebase?.sign_in_provider === 'password' && !token.email_verified) {
    throw new HttpsError('permission-denied', 'Verifikasi email terlebih dahulu.');
  }
  return request.auth.uid;
}

async function subscriptionCatalog() {
  const snapshot = await db.collection('subscriptions').get();
  return snapshot.docs.map(doc => ({...doc.data(), id: doc.id}))
    .sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
}

exports.preparePremiumPurchase = onCall({region}, async request => {
  const uid = requireUser(request);
  const plans = (await subscriptionCatalog()).filter(plan => plan.enabled === true);
  if (!plans.length) throw new HttpsError('failed-precondition', 'Paket langganan belum dikonfigurasi. Hubungi admin.');
  return db.runTransaction(async tx => {
    const profileRef = db.collection('users').doc(uid);
    const [profile, history] = await Promise.all([tx.get(profileRef), tx.get(accountRef(uid))]);
    if (!profile.exists) throw new HttpsError('failed-precondition', 'Profil belum tersinkron. Coba lagi.');
    const ever = everPremium(profile.data()) || history.data()?.hasEverBeenPremium === true;
    tx.set(accountRef(uid), {uid, hasEverBeenPremium: ever}, {merge: true});
    tx.update(profileRef, {hasEverBeenPremium: ever, userStatus: userStatus({...profile.data(), hasEverBeenPremium: ever})});
    return {eligibleForIntro: !ever, obfuscatedAccountId: accountId(uid), plans};
  });
});

async function synchronize(token, uid) {
  const ref = purchaseRef(token);
  // Disabled plans still verify renewals and existing paid subscriptions.
  const catalog = await subscriptionCatalog();
  const plans = Object.fromEntries(catalog.map(plan => [plan.id, null]));
  const verified = await db.runTransaction(async tx => {
    const [previous, profile, history, all] = await Promise.all([
      tx.get(ref), tx.get(db.collection('users').doc(uid)), tx.get(accountRef(uid)),
      tx.get(db.collection('playPurchases').where('uid', '==', uid)),
    ]);
    // Fetch again on transaction retries: out-of-order RTDNs must not overwrite a renewal/refund.
    const purchase = await fetchPurchase(token);
    try { assertOwner(purchase, accountId(uid), previous.data()?.uid, uid); }
    catch { throw new HttpsError('permission-denied', 'Pembelian ini milik akun Jajanku lain.'); }
    // Keep verifying historical introductory purchases after catalog migration.
    const legacyOffers = {monthly: 'first-month-half', 'six-monthly': 'first-six-months-half'};
    const verificationPlans = {...plans};
    for (const id of Object.keys(verificationPlans)) verificationPlans[id] = legacyOffers[id] || null;
    let parsed;
    try { parsed = readSubscription(purchase, Date.now(), verificationPlans); }
    catch { throw new HttpsError('invalid-argument', 'Produk atau masa langganan tidak dikenali.'); }
    const ever = everPremium(profile.data()) || history.data()?.hasEverBeenPremium === true;
    // Only the first successfully granted token can use an introductory offer.
    // Pending tokens do not reserve eligibility or count as having been VIP.
    if (rejectIntro(parsed, previous.data(), ever)) {
      tx.set(ref, {
        ...parsed, uid, token, active: false, rejected: true,
        refundRequested: previous.data()?.refundRequested === true,
        track: previous.data()?.refundRequested !== true,
        checkedAt: FieldValue.serverTimestamp(),
      });
      return {rejected: true, orderId: parsed.orderId,
        refundRequested: previous.data()?.refundRequested === true};
    }
    const linkedRef = purchase.linkedPurchaseToken ? purchaseRef(purchase.linkedPurchaseToken) : null;
    const linked = linkedRef ? await tx.get(linkedRef) : null;
    if (linked?.exists && linked.data().uid !== uid) {
      throw new HttpsError('permission-denied', 'Langganan sebelumnya milik akun lain.');
    }
    const record = {
      ...parsed, uid, token, packageName: packageName.value(),
      purchased: parsed.purchased || previous.data()?.purchased === true,
      replacedBy: previous.data()?.replacedBy || null,
      checkedAt: FieldValue.serverTimestamp(),
    };
    const replacesLinked = linked?.exists && parsed.purchased;
    const records = all.docs.filter(doc => doc.id !== ref.id &&
      !(replacesLinked && doc.id === linkedRef.id)).map(doc => doc.data());
    records.push(record);
    const active = chooseEntitlement(records);
    tx.set(ref, record);
    if (replacesLinked) tx.update(linkedRef, {active: false, track: false, replacedBy: ref.id});
    tx.set(accountRef(uid), {uid, hasEverBeenPremium: ever || record.purchased}, {merge: true});
    // Account deletion must never be undone by a renewal notification.
    if (profile.exists) {
      const latest = active || records.filter(r => r.purchased && r.end != null)
        .sort((a, b) => b.end - a.end)[0];
      tx.update(profile.ref, {
        plan: active ? 'premium' : 'free',
        userStatus: userStatus({plan: active ? 'premium' : 'free', hasEverBeenPremium: ever || record.purchased}),
        PremiumStartedAt: latest?.start != null ? Timestamp.fromMillis(latest.start) : null,
        PremiumEndedAt: latest?.end != null ? Timestamp.fromMillis(latest.end) : null,
        hasEverBeenPremium: ever || record.purchased,
        premiumAutoRenewing: active?.autoRenewing === true,
        premiumSubscriptionState: parsed.state,
      });
    }
    // Lifetime is an independent admin grant. Billing fields continue describing
    // the Play subscription, so removing the grant falls back to paid access.
    return {purchase, parsed, active: !!active || profile.data()?.premiumLifetime === true};
  });
  // Persist the rejection so notification redelivery never grants the purchase.
  if (verified.rejected) {
    if (!verified.refundRequested) {
      if (!verified.orderId) throw new Error('Rejected purchase has no refundable order');
      await playRequest(`orders/${encodeURIComponent(verified.orderId)}:refund?revoke=true`, 'POST');
      await ref.update({refundRequested: true, track: false});
    }
    throw new HttpsError('failed-precondition', 'Akun sudah pernah premium. Pembelian diskon ditolak dan pengembalian dana diminta.');
  }
  if (verified.parsed.purchased && verified.purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
    await playRequest(`purchases/subscriptions/${PRODUCT_ID}/tokens/${encodeURIComponent(token)}:acknowledge`, 'POST', {});
  }
  return {active: verified.active, pending: !verified.parsed.purchased};
}

exports.verifyPremiumPurchase = onCall({region}, async request => {
  const uid = requireUser(request);
  const token = request.data?.purchaseToken;
  if (typeof token !== 'string' || token.length < 8 || token.length > 4096) {
    throw new HttpsError('invalid-argument', 'Token pembelian tidak valid.');
  }
  if (!(await db.collection('users').doc(uid).get()).exists) {
    throw new HttpsError('failed-precondition', 'Profil belum tersinkron.');
  }
  try { return await synchronize(token, uid); }
  catch (error) {
    if (error instanceof HttpsError) throw error;
    // Never log raw Google API errors: they can contain purchase tokens in URLs.
    logger.error('Play purchase verification failed', {code: error.code || 'unknown'});
    throw new HttpsError('unavailable', 'Pembayaran belum dapat diverifikasi. Pulihkan pembelian untuk mencoba lagi.');
  }
});

exports.googlePlayNotifications = onMessagePublished({region, topic: 'google-play-billing', retry: true}, async event => {
  try {
    const message = event.data.message.json;
    if (message.packageName !== packageName.value() || message.testNotification) return;
    const token = message.subscriptionNotification?.purchaseToken || message.voidedPurchaseNotification?.purchaseToken;
    if (!token) return;
    const previous = await purchaseRef(token).get();
    let uid = previous.data()?.uid;
    if (!uid) {
      const purchase = await fetchPurchase(token);
      const id = purchaseAccountId(purchase);
      if (typeof id !== 'string' || !/^[a-f0-9]{64}$/.test(id)) return;
      uid = (await db.collection('billingAccounts').doc(id).get()).data()?.uid;
    }
    if (!uid) return;
    await synchronize(token, uid);
  } catch (error) {
    if (error instanceof HttpsError && ['permission-denied', 'invalid-argument', 'failed-precondition'].includes(error.code)) {
      logger.warn('Play notification rejected', {code: error.code});
      return;
    }
    throw new Error('Play notification synchronization failed; retry required.');
  }
});

// Recovery for dropped notifications; process in pages, without logging tokens.
exports.reconcilePremiumPurchases = onSchedule({region, schedule: 'every 60 minutes', timeoutSeconds: 540}, async () => {
  let cursor;
  let failed = false;
  while (true) {
    let query = db.collection('playPurchases').where('track', '==', true).orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      const record = doc.data();
      try { await synchronize(record.token, record.uid); }
      catch { failed = true; logger.warn('Scheduled Play reconciliation failed', {purchaseId: doc.id}); }
    }
    cursor = page.docs.at(-1);
  }
  if (failed) throw new Error('Some Play purchases could not be reconciled.');
});


// Re-read the current document in a transaction to tolerate out-of-order events.
exports.syncUserStatus = onDocumentWritten({region, document: 'users/{uid}'}, async event => {
  const ref = db.collection('users').doc(event.params.uid);
  await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return;
    const status = userStatus(snapshot.data());
    if (snapshot.data().userStatus !== status) tx.update(ref, {userStatus: status});
  });
});

exports.previewPremiumVoucher = onCall({region}, async request => {
  const uid = requireUser(request);
  const name = request.data?.name;
  const subscriptionId = request.data?.subscriptionId;
  if (typeof name !== 'string' || !/^[a-z0-9_-]{1,80}$/.test(name) ||
      typeof subscriptionId !== 'string' || !/^[a-z0-9-]{1,80}$/.test(subscriptionId)) {
    throw new HttpsError('invalid-argument', 'Voucher atau paket tidak valid.');
  }
  const [profile, voucher, subscription] = await Promise.all([
    db.collection('users').doc(uid).get(), db.collection('vouchers').doc(name).get(),
    db.collection('subscriptions').doc(subscriptionId).get(),
  ]);
  if (!profile.exists || !subscription.exists || subscription.data().enabled !== true) {
    throw new HttpsError('failed-precondition', 'Profil atau paket tidak tersedia.');
  }
  const quote = voucherQuote(voucher.data(), {...subscription.data(), id: subscriptionId}, profile.data());
  if (!quote) throw new HttpsError('failed-precondition', 'Voucher tidak berlaku untuk akun atau paket ini.');
  return {...quote, title: voucher.data().title, name, checkoutSupported: false};
});
