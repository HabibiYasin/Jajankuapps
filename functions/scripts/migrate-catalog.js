'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {userStatus} = require('../catalog');
async function migrate(db, apply = false) {
  for (const [id, price, durationDays] of [['monthly', 10000, 30], ['six-monthly', 50000, 180]]) {
    const ref = db.collection('subscriptions').doc(id);
    if (apply) await ref.update({price, currency: 'IDR', durationDays,
      discountPercent: FieldValue.delete(), offerId: FieldValue.delete(), offerID: FieldValue.delete()});
    console.log(`${apply ? 'Updated' : 'Would update'} subscriptions/${id}: price=${price}, durationDays=${durationDays}`);
  }
  const voucher = {name: 'cobapremium', type: 'percentage', price: 75,
    eligibleUntil: Timestamp.fromDate(new Date('2027-01-02T00:00:00+07:00')),
    enabled: true, title: 'Cobain Premium', userStatus: 'free', subscriptionId: null};
  const ref = db.collection('vouchers').doc('cobapremium');
  if (apply) await db.runTransaction(async tx => {
    if (!(await tx.get(ref)).exists) tx.create(ref, voucher);
  });
  console.log(`${apply ? 'Ensured' : 'Would create'} vouchers/cobapremium`);
  let cursor, count = 0;
  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      if (apply) await db.runTransaction(async tx => {
        const current = await tx.get(doc.ref);
        if (current.exists) tx.update(doc.ref, {userStatus: userStatus(current.data())});
      });
      count++;
    }
    cursor = page.docs.at(-1);
  }
  console.log(`${apply ? 'Updated' : 'Would update'} userStatus on ${count} users`);
}
module.exports = {migrate};
if (require.main === module) {
  const {initializeApp, applicationDefault} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const args = process.argv.slice(2);
  const index = args.indexOf('--project');
  const projectId = index < 0 ? null : args[index + 1];
  if (!projectId || projectId.startsWith('--')) throw new Error('--project PROJECT_ID is required');
  initializeApp({credential: applicationDefault(), projectId});
  migrate(getFirestore(), args.includes('--apply')).catch(error => {console.error(error.message); process.exitCode = 1;});
}
