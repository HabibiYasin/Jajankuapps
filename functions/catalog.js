'use strict';
const userStatus = profile => profile?.hasEverBeenPremium !== true ? 'free'
  : profile.plan === 'premium' ? 'subscriber' : 'exsubscriber';

// Returns a catalog quote only; payment must still be verified with its provider.
function voucherQuote(voucher, subscription, profile, now = Date.now()) {
  const until = voucher?.eligibleUntil?.toMillis?.();
  if (voucher?.enabled !== true || !Number.isFinite(until) || now >= until ||
      voucher.userStatus !== userStatus(profile) ||
      (voucher.subscriptionId != null && voucher.subscriptionId !== subscription.id)) return null;
  const amount = voucher.price;
  const price = subscription.price;
  if (!Number.isSafeInteger(price) || price < 0 || !Number.isFinite(amount) || amount <= 0) return null;
  let discount;
  if (voucher.type === 'percentage' && amount <= 100) discount = Math.floor(price * amount / 100);
  else if (voucher.type === 'absolute' && Number.isSafeInteger(amount)) discount = amount;
  else return null;
  discount = Math.min(price, discount);
  return {price, discount, total: price - discount, currency: 'IDR'};
}
module.exports = {userStatus, voucherQuote};
