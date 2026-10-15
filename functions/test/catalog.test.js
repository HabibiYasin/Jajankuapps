'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {userStatus, voucherQuote} = require('../catalog');
const now = Date.parse('2026-10-15T00:00:00Z');
const expiry = Date.parse('2027-01-01T17:00:00Z');
const voucher = {enabled:true, type:'percentage', price:75, userStatus:'free', subscriptionId:null,
  eligibleUntil:{toMillis: () => expiry}};
const plan = {id:'monthly', price:10000};
test('user status follows explicit history and plan', () => {
  assert.equal(userStatus({}), 'free');
  assert.equal(userStatus({hasEverBeenPremium:false, plan:'premium'}), 'free');
  assert.equal(userStatus({hasEverBeenPremium:true, plan:'premium'}), 'subscriber');
  assert.equal(userStatus({hasEverBeenPremium:true, plan:'free'}), 'exsubscriber');
});
test('percentage and absolute quotes clamp at zero', () => {
  assert.equal(voucherQuote(voucher, plan, {}, now).total, 2500);
  assert.equal(voucherQuote(voucher, {...plan, price:50000}, {}, now).total, 12500);
  assert.equal(voucherQuote({...voucher,type:'absolute',price:10000}, {...plan,price:50000}, {}, now).total, 40000);
  assert.equal(voucherQuote({...voucher,type:'absolute',price:20000}, plan, {}, now).total, 0);
});
test('expiry, disabled, audience, subscription and malformed discounts are rejected', () => {
  for (const patch of [{enabled:false}, {userStatus:'subscriber'}, {subscriptionId:'six-monthly'},
    {price:101}, {price:-1}, {price:NaN}, {type:'unknown'}, {eligibleUntil:null}]) {
    assert.equal(voucherQuote({...voucher,...patch}, plan, {}, now), null);
  }
  assert.equal(voucherQuote(voucher, plan, {}, expiry), null);
  assert.ok(voucherQuote(voucher, plan, {}, expiry-1));
  assert.equal(voucherQuote(voucher, plan, {hasEverBeenPremium:true,plan:'free'}, now), null);
});
