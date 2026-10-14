'use strict';

const {createHash} = require('node:crypto');
const PRODUCT_ID = 'jajanku_premium';
const PLANS = {monthly: 'first-month-half', 'six-monthly': 'first-six-months-half'};
const hash = value => createHash('sha256').update(value).digest('hex');
const everPremium = profile => profile?.hasEverBeenPremium === true ||
  profile?.premiumLifetime === true ||
  ['premium', 'vip'].includes(profile?.plan) ||
  profile?.PremiumStartedAt != null || profile?.PremiumEndedAt != null;

function readSubscription(purchase, now = Date.now(), plans = PLANS) {
  if (!['SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_PAUSED',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_CANCELED',
    'SUBSCRIPTION_STATE_EXPIRED', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED'].includes(purchase.subscriptionState)) {
    throw new Error('Unsupported subscription state');
  }
  const items = (purchase.lineItems || []).filter(item =>
    item.productId === PRODUCT_ID && Object.hasOwn(plans, item.offerDetails?.basePlanId));
  if (items.length !== 1) throw new Error('Unsupported subscription');
  const item = items[0];
  const {basePlanId, offerId} = item.offerDetails;
  if (offerId && offerId !== plans[basePlanId]) throw new Error('Unsupported offer');
  const pending = ['SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED']
    .includes(purchase.subscriptionState);
  const start = Date.parse(purchase.startTime);
  const end = Date.parse(item.expiryTime);
  if (!pending && (!Number.isFinite(start) || !Number.isFinite(end) || end <= start)) {
    throw new Error('Invalid subscription dates');
  }
  const entitled = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED'].includes(purchase.subscriptionState);
  return {
    basePlanId, offerId: offerId || null,
    start: Number.isFinite(start) ? start : null,
    end: Number.isFinite(end) ? end : null,
    active: entitled && start <= now && end > now,
    purchased: !pending && Number.isFinite(start),
    autoRenewing: item.autoRenewingPlan?.autoRenewEnabled === true,
    state: purchase.subscriptionState,
    track: !['SUBSCRIPTION_STATE_EXPIRED', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED']
      .includes(purchase.subscriptionState),
    orderId: item.latestSuccessfulOrderId || purchase.latestOrderId || null,
  };
}

const purchaseAccountId = purchase => purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId ||
  purchase.outOfAppPurchaseContext?.expiredExternalAccountIdentifiers?.obfuscatedExternalAccountId;

function assertOwner(purchase, expectedId, previousUid, uid) {
  if (previousUid && previousUid !== uid) throw new Error('Purchase belongs to another account');
  const id = purchaseAccountId(purchase);
  // Play removes out-of-app context after acknowledgement. The verified token
  // binding remains authoritative when the API no longer includes an account ID.
  if (id !== expectedId && !(id == null && previousUid === uid)) {
    throw new Error('Purchase account does not match');
  }
}

function chooseEntitlement(records, now = Date.now()) {
  return records.filter(record => record.active && record.end > now && !record.replacedBy && !record.rejected)
    .sort((a, b) => b.end - a.end)[0] || null;
}

const rejectIntro = (parsed, previous, ever) => previous?.rejected === true ||
  (parsed.purchased && !!parsed.offerId && !previous?.purchased && ever);

module.exports = {PRODUCT_ID, PLANS, hash, everPremium, readSubscription, assertOwner, chooseEntitlement, rejectIntro, purchaseAccountId};
