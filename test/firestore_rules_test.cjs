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
  const tx = 'users/alice/transactions/one';
  await request('GET',tx,null,undefined,403);
  await request('PATCH',tx,null,transaction,403);
  await request('PATCH',tx,'alice',transaction);
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
  const marker = 'users/alice/imports/one';
  await request('PATCH',marker,'bob',{completed:{booleanValue:true}},403);
  await request('PATCH',marker,'alice',{completed:{booleanValue:true}});
  await request('GET',marker,'alice');
  await request('GET',marker,'bob',undefined,403);
  await request('DELETE',marker,'alice',undefined,403);
  await request('PATCH',marker,'alice',{completed:{booleanValue:false}},403);
  await request('PATCH','users/alice/anything/one','alice',{value:{booleanValue:true}},403);
  await request('DELETE',tx,'alice');
  console.log(`${checks} Firestore rules checks passed.`);
})().catch(error => {console.error(error); process.exitCode = 1;});
