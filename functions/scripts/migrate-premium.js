'use strict';
// Admin-only, dry-run by default. Never ships inside the app.
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {hash, everPremium} = require('../premium');
const args = process.argv.slice(2);
const index = args.indexOf('--project');
const projectId = index < 0 ? null : args[index + 1];
if (!projectId || projectId.startsWith('--')) throw new Error('An explicit --project PROJECT_ID is required.');
initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
const apply = args.includes('--apply');
(async () => {
  let cursor;
  let updated = 0;
  let missingDates = 0;
  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      const inspect = data => {
        const patch = {};
        if (!Object.hasOwn(data, 'PremiumStartedAt')) patch.PremiumStartedAt = null;
        if (!Object.hasOwn(data, 'PremiumEndedAt')) patch.PremiumEndedAt = null;
        if (!Object.hasOwn(data, 'premiumLifetime')) patch.premiumLifetime = false;
        if (!Object.hasOwn(data, 'hasEverBeenPremium') || everPremium(data)) patch.hasEverBeenPremium = everPremium(data);
        return patch;
      };
      const data = doc.data();
      if (data.premiumLifetime !== true && ['premium', 'vip'].includes(data.plan) && (!data.PremiumStartedAt || !data.PremiumEndedAt)) {
        missingDates++;
        console.log(`Needs real premium dates: users/${doc.id}`);
      }
      if (apply) {
        await db.runTransaction(async tx => {
          const current = await tx.get(doc.ref);
          const historyRef = db.collection('billingAccounts').doc(hash(`${projectId}:${doc.id}`));
          const history = await tx.get(historyRef);
          if (!current.exists) return;
          const ever = everPremium(current.data()) || history.data()?.hasEverBeenPremium === true;
          tx.update(doc.ref, {...inspect(current.data()), hasEverBeenPremium: ever});
          tx.set(historyRef, {uid: doc.id, hasEverBeenPremium: ever}, {merge: true});
        });
      }
      updated++;
    }
    cursor = page.docs.at(-1);
  }
  console.log(JSON.stringify({projectId, mode: apply ? 'apply' : 'dry-run', inspected: updated, missingDates}));
})().catch(error => {console.error(error.message); process.exitCode = 1;});
