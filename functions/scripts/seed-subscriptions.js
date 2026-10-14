'use strict';
// Creates missing catalog documents only. Existing admin changes are preserved.
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const args = process.argv.slice(2);
const index = args.indexOf('--project');
const projectId = index < 0 ? null : args[index + 1];
if (!projectId || projectId.startsWith('--')) throw new Error('--project PROJECT_ID is required');
const plans = [
  {id: 'monthly', title: '1 bulan', billingPeriod: 'P1M', offerId: 'first-month-half', discountPercent: 50, enabled: true, sortOrder: 1},
  {id: 'six-monthly', title: '6 bulan', billingPeriod: 'P6M', offerId: 'first-six-months-half', discountPercent: 50, enabled: true, sortOrder: 2},
];
initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
(async () => {
  for (const {id, ...data} of plans) {
    if (!args.includes('--apply')) { console.log(`Would create if missing: subscriptions/${id}`, data); continue; }
    await db.runTransaction(async tx => {
      const ref = db.collection('subscriptions').doc(id);
      if (!(await tx.get(ref)).exists) tx.create(ref, data);
    });
    console.log(`Catalog ready: subscriptions/${id}`);
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
