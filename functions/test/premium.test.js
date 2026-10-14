'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {readSubscription, everPremium, assertOwner, chooseEntitlement, rejectIntro} = require('../premium');
const now = Date.parse('2026-10-13T00:00:00Z');
function purchase(state = 'ACTIVE') {
  return {
    startTime: '2026-10-01T00:00:00Z', subscriptionState: `SUBSCRIPTION_STATE_${state}`,
    externalAccountIdentifiers: {obfuscatedExternalAccountId: 'alice-id'},
    lineItems: [{productId: 'jajanku_premium', expiryTime: '2026-11-01T00:00:00Z',
      offerDetails: {basePlanId: 'monthly'}, autoRenewingPlan: {autoRenewEnabled: true}}],
  };
}

test('cancellation keeps paid time; grace period retains access; hold/pause/expiry revoke it', () => {
  for (const state of ['ACTIVE', 'CANCELED', 'IN_GRACE_PERIOD']) {
    assert.equal(readSubscription(purchase(state), now).active, true, state);
  }
  for (const state of ['ON_HOLD', 'PAUSED', 'EXPIRED', 'PENDING', 'PENDING_PURCHASE_CANCELED']) {
    assert.equal(readSubscription(purchase(state), now).active, false, state);
  }
  assert.equal(readSubscription(purchase(), Date.parse('2026-11-01T00:00:00Z')).active, false);
});

test('pending does not require dates, grant access, or consume first-purchase eligibility', () => {
  const p = purchase('PENDING');
  delete p.startTime;
  delete p.lineItems[0].expiryTime;
  const parsed = readSubscription(p, now);
  assert.equal(parsed.purchased, false);
  assert.equal(parsed.active, false);
  assert.equal(parsed.start, null);
  assert.equal(rejectIntro({...parsed, offerId: 'first-month-half'}, {}, true), false);
});

test('reject mismatched product/plan/offer, malformed dates and unknown states', () => {
  for (const mutate of [
    p => { p.lineItems[0].productId = 'another_product'; },
    p => { p.lineItems[0].offerDetails.basePlanId = 'annual'; },
    p => { p.lineItems[0].offerDetails.offerId = 'unapproved-discount'; },
    p => { p.lineItems[0].expiryTime = 'invalid'; },
    p => { p.startTime = '2027-01-01T00:00:00Z'; },
    p => { p.subscriptionState = 'UNSPECIFIED'; },
  ]) {
    const p = purchase(); mutate(p);
    assert.throws(() => readSubscription(p, now));
  }
});

test('ever-premium survives expiry and recognizes legacy VIP and dated accounts', () => {
  assert.equal(everPremium({plan: 'free'}), false);
  for (const profile of [{plan: 'vip'}, {plan: 'premium'},
    {plan: 'free', premiumLifetime: true},
    {plan: 'free', PremiumEndedAt: new Date(0)}, {plan: 'free', hasEverBeenPremium: true}]) {
    assert.equal(everPremium(profile), true);
  }
});

test('restore/replay/renewal is allowed for same owner, never transferred to another account', () => {
  assert.doesNotThrow(() => assertOwner(purchase(), 'alice-id', 'alice', 'alice'));
  assert.throws(() => assertOwner(purchase(), 'alice-id', 'alice', 'bob'));
  assert.throws(() => assertOwner(purchase(), 'bob-id', undefined, 'bob'));
  const missing = purchase(); delete missing.externalAccountIdentifiers;
  assert.throws(() => assertOwner(missing, 'alice-id', undefined, 'alice'));
  missing.outOfAppPurchaseContext = {expiredExternalAccountIdentifiers: {obfuscatedExternalAccountId: 'alice-id'}};
  assert.doesNotThrow(() => assertOwner(missing, 'alice-id', undefined, 'alice'));
  delete missing.outOfAppPurchaseContext;
  assert.doesNotThrow(() => assertOwner(missing, 'alice-id', 'alice', 'alice'));
});

test('intro only once, but duplicate delivery and renewal of the granted token are idempotent', () => {
  const parsed = {...readSubscription(purchase(), now), offerId: 'first-month-half'};
  assert.equal(rejectIntro(parsed, undefined, false), false);
  assert.equal(rejectIntro(parsed, undefined, true), true);
  assert.equal(rejectIntro(parsed, {purchased: false}, true), true);
  assert.equal(rejectIntro(parsed, {purchased: true}, true), false);
  assert.equal(rejectIntro(parsed, {purchased: true, rejected: true}, false), true);
  assert.equal(rejectIntro({...parsed, offerId: null}, undefined, true), false);
});

test('old expired or replaced tokens cannot remove a newer active entitlement', () => {
  const valid = {active: true, end: now + 1000, name: 'new'};
  assert.equal(chooseEntitlement([
    {active: false, end: now + 99999}, valid,
    {active: true, end: now + 99999, replacedBy: 'new'},
    {active: true, end: now + 99999, rejected: true},
    {active: true, end: now - 1},
  ], now), valid);
  assert.equal(chooseEntitlement([valid], now + 1000), null);
});


test('catalog accepts a new base plan without changing verification code', () => {
  const p = purchase();
  p.lineItems[0].offerDetails = {basePlanId: 'annual', offerId: 'annual-intro'};
  assert.equal(readSubscription(p, now, {annual: 'annual-intro'}).active, true);
  assert.throws(() => readSubscription(p, now, {}));
  assert.throws(() => readSubscription(p, now, {annual: null}));
});
