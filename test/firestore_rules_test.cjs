// Run: firebase emulators:exec --only firestore --project demo-jajanku
//      --config firebase.emulator.json "node test/firestore_rules_test.cjs"
const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !host.startsWith('127.0.0.1:')) throw new Error('Local emulator required');
const base = `http://${host}/v1/projects/demo-jajanku/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg:'none',typ:'JWT'})}.${encode({sub:uid,user_id:uid,
    aud:'demo-jajanku',iss:'https://securetoken.google.com/demo-jajanku',
    iat:now,exp:now+3600,firebase:{sign_in_provider:'custom'}})}.`;
}
const transaction = {
  merchant:{stringValue:'Warung'}, nominalStr:{stringValue:'Rp62.500'},
  dateTime:{timestampValue:'2026-10-01T05:00:00Z'}, category:{stringValue:'Makanan'},
  source:{stringValue:'QRIS'}, numericNominal:{doubleValue:62500},
};
const budget = {daily:{doubleValue:50000},weekly:{doubleValue:350000},monthly:{doubleValue:1500000}};
let checks = 0;
async function request(method, path, uid, fields, expected = 200) {
  const result = await fetch(`${base}/${path}`, {
    method, headers:{'Content-Type':'application/json', ...(uid ? {Authorization:`Bearer ${token(uid)}`} : {})},
    body: fields ? JSON.stringify({fields}) : undefined,
  });
  const body = await result.text();
  assert.equal(result.status, expected, `${method} ${path} as ${uid}: ${body}`);
  checks++;
}
async function query(uid, owner, expected) {
  const result = await fetch(`${base}/users/${owner}:runQuery`, {
    method:'POST', headers:{'Content-Type':'application/json',Authorization:`Bearer ${token(uid)}`},
    body:JSON.stringify({structuredQuery:{from:[{collectionId:'transactions'}]}}),
  });
  assert.equal(result.status, expected, await result.text()); checks++;
}
(async () => {
  const updatePath = 'app_config/android_update';
  const updatePolicy = {enabled:{booleanValue:true},minimumBuildNumber:{integerValue:'4'}};
  // Seed only the local emulator as admin, then exercise public/client access.
  const seeded = await fetch(`${base}/${updatePath}`, {
    method: 'PATCH', headers: {'Content-Type':'application/json', Authorization:'Bearer owner'},
    body: JSON.stringify({fields:updatePolicy}),
  });
  assert.equal(seeded.status, 200, await seeded.text());
  await request('GET', updatePath, null);
  await request('GET', updatePath, 'alice');
  await request('PATCH', updatePath, null, updatePolicy, 403);
  await request('PATCH', updatePath, 'alice', updatePolicy, 403);
  await request('DELETE', updatePath, 'alice', undefined, 403);
  await request('GET', 'app_config', null, undefined, 403);
  await request('GET', 'app_config/private', 'alice', undefined, 403);
  async function profileWrite(uid, plan, create = false, extra = {}) {
    const result = await fetch(`${base}:commit`, {
      method: 'POST', headers: {'Content-Type':'application/json', Authorization:`Bearer ${token(uid)}`},
      body: JSON.stringify({writes: [{
        update: {name: `projects/demo-jajanku/databases/(default)/documents/users/${uid}`,
          fields: {email:{stringValue:'test@example.com'},displayName:{stringValue:''},
            providers:{arrayValue:{values:[{stringValue:'password'}]}},plan:{stringValue:plan}, ...extra}},
        updateTransforms: [ ...(create ? [{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}] : []),
          {fieldPath:'lastLoginAt',setToServerValue:'REQUEST_TIME'}],
        ...(create ? {} : {updateMask:{fieldPaths:['email','displayName','providers','plan']}}),
      }]}),
    });
    checks++;
    return result.status;
  }
  assert.equal(await profileWrite('profile-user','vip',true),403);
  assert.equal(await profileWrite('profile-user','free',true),200);
  await request('GET','users/profile-user','profile-user');
  await request('GET','users/profile-user','bob',undefined,403);
  assert.equal(await profileWrite('profile-user','vip'),403);
  assert.equal(await profileWrite('profile-user','free'),200);
  assert.equal(await profileWrite('lifetime-user','free',true,{premiumLifetime:{booleanValue:true}}),403);
  assert.equal(await profileWrite('lifetime-user','free',true,{premiumLifetime:{stringValue:'true'}}),403);
  assert.equal(await profileWrite('lifetime-user','free',true,{premiumLifetime:{booleanValue:false}}),200);
  await request('PATCH', 'users/lifetime-user?updateMask.fieldPaths=premiumLifetime', 'lifetime-user', {premiumLifetime:{booleanValue:true}}, 403);
  for (const [field, value] of Object.entries({
    PremiumStartedAt: {timestampValue: '2026-10-01T00:00:00Z'},
    PremiumEndedAt: {timestampValue: '2027-10-01T00:00:00Z'},
    hasEverBeenPremium: {booleanValue: true},
    premiumLifetime: {booleanValue: true},
    premiumAutoRenewing: {booleanValue: true},
    premiumSubscriptionState: {stringValue: 'SUBSCRIPTION_STATE_ACTIVE'},
  })) {
    await request('PATCH', `users/profile-user?updateMask.fieldPaths=${field}`, 'profile-user', {[field]: value}, 403);
  }
  for (const collection of ['billingAccounts', 'playPurchases']) {
    await request('GET', `${collection}/secret`, 'profile-user', undefined, 403);
    await request('PATCH', `${collection}/secret`, 'profile-user', {hasEverBeenPremium: {booleanValue: false}}, 403);
    await request('DELETE', `${collection}/secret`, 'profile-user', undefined, 403);
  }
  const avatarPath = 'users/profile-user?updateMask.fieldPaths=avatarCode';
  for (let code = 1; code <= 6; code++) {
    await request('PATCH', avatarPath, 'profile-user', {avatarCode:{integerValue:String(code)}});
  }
  for (const value of [{integerValue:'0'}, {integerValue:'7'}, {doubleValue:1.5}, {stringValue:'1'}]) {
    await request('PATCH', avatarPath, 'profile-user', {avatarCode:value}, 403);
  }
  await request('PATCH', avatarPath, 'bob', {avatarCode:{integerValue:'1'}}, 403);
  await request('DELETE','users/profile-user','profile-user');
  const tx = 'users/alice/transactions/one';
  await request('GET',tx,null,undefined,403);
  await request('PATCH',tx,null,transaction,403);
  await request('PATCH',tx,'alice',transaction);
  await request('PATCH',tx,'alice',{...transaction,paymentMethod:{stringValue:'PayLater'}});
  await request('PATCH',tx,'alice',{...transaction,paymentMethod:{stringValue:'Unknown'}},403);
  await request('GET',tx,'alice');
  await query('alice','alice',200);
  await query('bob','alice',403);
  await request('GET',tx,'bob',undefined,403);
  await request('PATCH',tx,'bob',transaction,403);
  await request('DELETE',tx,'bob',undefined,403);
  await request('PATCH',tx,'alice',{...transaction,numericNominal:{doubleValue:-1}},403);
  await request('PATCH',tx,'alice',{...transaction,admin:{booleanValue:true}},403);
  await request('PATCH',tx,'alice',{...transaction,dateTime:{stringValue:'not a timestamp'}},403);
  await request('PATCH',tx,'alice',{merchant:{stringValue:'incomplete'}},403);
  await request('PATCH',tx,'alice',{...transaction,merchant:{stringValue:'Edited'}});
  const settings = 'users/alice/settings/budget';
  await request('PATCH',settings,'alice',budget);
  await request('GET',settings,'bob',undefined,403);
  await request('PATCH',settings,'bob',budget,403);
  await request('PATCH',settings,'alice',{...budget,daily:{doubleValue:0}},403);
  await request('PATCH',settings,'alice',{...budget,weekly:{stringValue:'5000'}},403);
  const categoryList = (...values) => ({arrayValue:{values:values.map(value => ({stringValue:value}))}});
  await request('PATCH',settings,'alice',{...budget,categories:categoryList('Jajan','Makanan','Minuman','Belanja')});
  await request('PATCH',settings,'bob',{...budget,categories:categoryList('Jajan')},403);
  await request('PATCH',settings,'alice',{...budget,categories:categoryList()},403);
  await request('PATCH',settings,'alice',{...budget,categories:categoryList('Tidak dikenal')},403);
  await request('PATCH',settings,'alice',{...budget,categories:categoryList('Jajan','Jajan')},403);
  await request('PATCH',settings,'alice',{...budget,categories:{stringValue:'Jajan'}},403);
  const marker = 'users/alice/imports/one';
  await request('PATCH',marker,'bob',{completed:{booleanValue:true}},403);
  await request('PATCH',marker,'alice',{completed:{booleanValue:true}});
  await request('GET',marker,'alice');
  await request('GET',marker,'bob',undefined,403);
  await request('DELETE',marker,'alice');
  await request('PATCH',marker,'alice',{completed:{booleanValue:false}},403);
  await request('PATCH','users/alice/anything/one','alice',{value:{booleanValue:true}},403);
  await request('DELETE',tx,'alice');
  console.log(`${checks} Firestore rules checks passed.`);
})().catch(error => {console.error(error); process.exitCode = 1;});
