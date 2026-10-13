'use strict';
// Real Firestore transactions, fake Play transport. No external payment calls.
const assert = require('node:assert/strict');
if (!process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) throw new Error('Local emulator required');
process.env.GCLOUD_PROJECT = 'demo-jajanku';
process.env.PLAY_PACKAGE_NAME = 'com.jajanku.app.dev';
const {GoogleAuth} = require('google-auth-library');
const {getFirestore} = require('firebase-admin/firestore');
const {hash} = require('../premium');
const purchases = new Map();
let acknowledges = 0;
let refunds = 0;
GoogleAuth.prototype.getClient = async () => ({request: async ({url, method}) => {
  if (url.endsWith(':acknowledge') && method === 'POST') { acknowledges++; return {data: {}}; }
  if (url.includes(':refund?revoke=true') && method === 'POST') { refunds++; return {data: {}}; }
  const token = decodeURIComponent(url.split('/tokens/')[1]);
  assert.ok(purchases.has(token), 'Only fixture purchase tokens are accepted');
  return {data: structuredClone(purchases.get(token))};
}});
const api = require('../index');
const db = getFirestore();
const user = uid => db.collection('users').doc(uid);
const auth = uid => ({uid, token: {email_verified: true, firebase: {sign_in_provider: 'password'}}});
const verify = (uid, token) => api.verifyPremiumPurchase.run({auth: auth(uid), data: {purchaseToken: token}});
const prepare = uid => api.preparePremiumPurchase.run({auth: auth(uid), data: {}});
function fixture(uid, {offer = true, state = 'ACTIVE', end = Date.now() + 86400000} = {}) {
  return {
    startTime: new Date(Date.now() - 86400000).toISOString(),
    subscriptionState: `SUBSCRIPTION_STATE_${state}`,
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: {obfuscatedExternalAccountId: hash(`demo-jajanku:${uid}`)},
    lineItems: [{productId: 'jajanku_premium', expiryTime: new Date(end).toISOString(),
      latestSuccessfulOrderId: 'GPA.test.order', autoRenewingPlan: {autoRenewEnabled: true},
      offerDetails: {basePlanId: 'monthly', ...(offer ? {offerId: 'first-month-half'} : {})}}],
  };
}

(async () => {
  await assert.rejects(api.preparePremiumPurchase.run({data: {}}), {code: 'unauthenticated'});
  await user('billing-alice').set({plan: 'free', hasEverBeenPremium: false});
  await user('billing-bob').set({plan: 'free'});
  assert.equal((await prepare('billing-alice')).eligibleForIntro, true);
  const first = 'token-alice-first';
  purchases.set(first, fixture('billing-alice'));
  assert.equal((await verify('billing-alice', first)).active, true);
  let profile = (await user('billing-alice').get()).data();
  assert.equal(profile.plan, 'premium');
  assert.equal(profile.hasEverBeenPremium, true);
  assert.ok(profile.PremiumEndedAt.toMillis() > Date.now());
  assert.equal((await prepare('billing-alice')).eligibleForIntro, false);
  assert.equal(acknowledges, 1);
  // Duplicate delivery must not be mistaken for a second introductory purchase.
  assert.equal((await verify('billing-alice', first)).active, true);
  await assert.rejects(verify('billing-bob', first), {code: 'permission-denied'});
  assert.equal((await user('billing-bob').get()).data().plan, 'free');

  const renewed = Date.now() + 60 * 86400000;
  purchases.set(first, fixture('billing-alice', {end: renewed}));
  await verify('billing-alice', first);
  assert.equal((await user('billing-alice').get()).data().PremiumEndedAt.toMillis(), renewed);
  purchases.set(first, fixture('billing-alice', {state: 'CANCELED'}));
  assert.equal((await verify('billing-alice', first)).active, true);
  purchases.set(first, fixture('billing-alice', {state: 'ON_HOLD'}));
  assert.equal((await verify('billing-alice', first)).active, false);
  assert.equal((await user('billing-alice').get()).data().hasEverBeenPremium, true);

  // Another discounted token is rejected and refunded once, including redelivery.
  const repeated = 'token-alice-repeat';
  purchases.set(repeated, fixture('billing-alice'));
  await assert.rejects(verify('billing-alice', repeated), {code: 'failed-precondition'});
  await assert.rejects(verify('billing-alice', repeated), {code: 'failed-precondition'});
  assert.equal(refunds, 1);
  const normal = 'token-alice-normal';
  purchases.set(normal, fixture('billing-alice', {offer: false}));
  assert.equal((await verify('billing-alice', normal)).active, true);
  // Old expiry cannot downgrade the new paid subscription.
  purchases.set(first, fixture('billing-alice', {state: 'EXPIRED', end: Date.now() - 1000}));
  assert.equal((await verify('billing-alice', first)).active, true);

  // Deleting/recreating the client profile cannot reset the private account history.
  await user('billing-alice').delete();
  await user('billing-alice').set({plan: 'free'});
  assert.equal((await prepare('billing-alice')).eligibleForIntro, false);
  assert.equal((await user('billing-alice').get()).data().hasEverBeenPremium, true);

  const pending = 'token-bob-pending';
  purchases.set(pending, fixture('billing-bob', {state: 'PENDING'}));
  const count = acknowledges;
  assert.equal((await verify('billing-bob', pending)).pending, true);
  assert.equal(acknowledges, count);
  assert.equal((await prepare('billing-bob')).eligibleForIntro, true);
  purchases.set(pending, fixture('billing-bob'));
  assert.equal((await verify('billing-bob', pending)).active, true);
  assert.equal((await prepare('billing-bob')).eligibleForIntro, false);
  // Lifetime is independent of billing, survives expiry, and can be revoked.
  await user('billing-tester').set({plan: 'free', premiumLifetime: true});
  assert.equal((await prepare('billing-tester')).eligibleForIntro, false);
  assert.equal((await user('billing-tester').get()).data().hasEverBeenPremium, true);
  await user('billing-bob').update({premiumLifetime: true, hasEverBeenPremium: true});
  purchases.set(pending, fixture('billing-bob', {state: 'EXPIRED', end: Date.now() - 1000}));
  assert.equal((await verify('billing-bob', pending)).active, true);
  assert.equal((await user('billing-bob').get()).data().premiumLifetime, true);
  assert.equal((await user('billing-bob').get()).data().plan, 'free');
  await user('billing-bob').update({premiumLifetime: false});
  assert.equal((await verify('billing-bob', pending)).active, false);
  assert.equal((await prepare('billing-bob')).eligibleForIntro, false);
  purchases.set(pending, fixture('billing-bob'));
  assert.equal((await verify('billing-bob', pending)).active, true);
  // Out-of-app resubscription is mapped from Google's expired account context.
  const external = 'token-alice-external';
  const outOfApp = fixture('billing-alice', {offer: false});
  outOfApp.outOfAppPurchaseContext = {expiredExternalAccountIdentifiers: outOfApp.externalAccountIdentifiers};
  delete outOfApp.externalAccountIdentifiers;
  purchases.set(external, outOfApp);
  const notify = token => api.googlePlayNotifications.run({data: {message: {json: {
    packageName: 'com.jajanku.app.dev', subscriptionNotification: {purchaseToken: token},
  }}}});
  await notify(external);
  assert.equal((await user('billing-alice').get()).data().plan, 'premium');
  delete outOfApp.outOfAppPurchaseContext;
  purchases.set(external, outOfApp);
  await notify(external); // Context is absent after acknowledgement; persisted binding still works.
  await user('billing-alice').delete();
  await notify(external);
  assert.equal((await user('billing-alice').get()).exists, false);
  console.log('Billing emulator integration checks passed (purchase, restore, renewal, hold, expiry, refund, ownership, pending, history).');
  await db.terminate();
})().catch(error => {console.error(error); process.exitCode = 1;});
