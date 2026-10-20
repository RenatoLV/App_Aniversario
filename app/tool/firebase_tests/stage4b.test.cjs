'use strict';
// Integration against actual HTTP Functions, Auth and Firestore emulators.
const {test,after}=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),path=require('node:path');
const {createRequire}=require('node:module');
const deps=createRequire(path.join(__dirname,'../../functions/package.json'));
const {initializeApp,cert}=deps('firebase-admin/app');
const {getFirestore}=deps('firebase-admin/firestore');
const {getAuth}=deps('firebase-admin/auth');
const {digest}=require('../../functions/economy_v2/service.cjs');
const project='demo-lucky-readiness';
assert.equal(process.env.GCLOUD_PROJECT,project);assert.equal(process.versions.node.split('.')[0],'22');
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) assert.match(process.env[name]||'',/^127\.0\.0\.1:\d+$/);
const key=crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
const app=initializeApp({projectId:project,credential:cert({projectId:project,clientEmail:`fixture@${project}.iam.gserviceaccount.com`,privateKey:key})});
const db=getFirestore(app),auth=getAuth(app),id=()=>crypto.randomBytes(16).toString('hex');
const endpoint=`http://127.0.0.1:15001/${project}/us-central1/`;
const ref=(uid,collection,key)=>db.doc(`economies_v2/${uid}/${collection}/${key}`);
async function authCall(method,body) {
  const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  assert.equal(response.status,200);return response.json();
}
async function user(participant=true) {
  const email=`${id()}@example.invalid`,password='local-test-password-only';
  const u=await authCall('signUp',{email,password,returnSecureToken:true});
  if(participant) await auth.setCustomUserClaims(u.localId,{economySandbox:true});
  return authCall('signInWithPassword',{email,password,returnSecureToken:true});
}
async function call(u,action,params={},options={}) {
  const response=await fetch(endpoint+(options.probe?'economyV2AppCheckProbe':'economyV2'),{
    method:'POST',headers:{'Content-Type':'application/json',...(u?{Authorization:`Bearer ${options.token||u.idToken}`}:{})},
    body:JSON.stringify({action,expectedOwnerUid:u?.localId,...params}),...(options.signal?{signal:options.signal}:{})});
  return {status:response.status,body:await response.json()};
}
async function initialize(u) {
  const op=id(),response=await call(u,'initialize',{operationId:op});
  assert.equal(response.status,200,JSON.stringify(response.body));assert.equal(response.body.receipt.status,'committed');
  return response.body.receipt;
}
async function ticket(u,source='sandbox.match.v1') {
  const ticketId=id();await ref(u.localId,'incomeTickets',ticketId).set({ownerUid:u.localId,source,
    issuer:'sandbox-fixture.v1',expiresAt:Date.now()+60000});return ticketId;
}
async function balance(u) {return (await call(u,'getWallet')).body.wallet.balance;}
async function rest(u,collection,key,method='GET',fields) {
  return fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/${collection}/${key}`,{
    method,headers:{'Content-Type':'application/json',...(u?{Authorization:`Bearer ${u.idToken}`}:{})},
    ...(fields?{body:JSON.stringify({fields})}:{})});
}
test('HTTP authentication: missing, malformed, expired, wrong audience, revoked and disabled tokens fail',async()=>{
  assert.equal((await call(null,'getWallet')).status,401);
  const u=await user();
  assert.equal((await call(u,'getWallet',{}, {token:'not-a-token'})).status,401);
  const changed=changes=>{
    const parts=u.idToken.split('.'),payload=JSON.parse(Buffer.from(parts[1],'base64url'));
    return [parts[0],Buffer.from(JSON.stringify({...payload,...changes})).toString('base64url'),parts[2]].join('.');
  };
  assert.equal((await call(u,'getWallet',{}, {token:changed({exp:1})})).status,401);
  assert.equal((await call(u,'getWallet',{}, {token:changed({aud:'different-project'})})).status,401);
  await new Promise(r=>setTimeout(r,1100));await auth.revokeRefreshTokens(u.localId);
  assert.equal((await call(u,'getWallet')).status,401,'revoked');
  const disabled=await user();await auth.updateUser(disabled.localId,{disabled:true});
  assert.equal((await call(disabled,'getWallet')).status,401,'disabled');
});
test('HTTP App Check enforced path rejects missing and malformed attestations',async()=>{
  const u=await user();assert.equal((await call(u,'getWallet',{}, {probe:true})).status,403);
  const response=await fetch(endpoint+'economyV2AppCheckProbe',{method:'POST',headers:{
    'Content-Type':'application/json',Authorization:`Bearer ${u.idToken}`,'X-Firebase-AppCheck':'malformed'},
    body:JSON.stringify({action:'getWallet',expectedOwnerUid:u.localId})});
  assert.equal(response.status,403);
});
test('initialization policy and duplicate taps: zero legacy import, one bootstrap movement',async()=>{
  const outsider=await user(false);
  assert.equal((await call(outsider,'initialize',{operationId:id()})).status,403);
  const u=await user(),operationId=id();
  assert.equal((await call(u,'getWallet')).body.wallet,null);
  const responses=await Promise.all(Array.from({length:5},()=>call(u,'initialize',{operationId})));
  responses.forEach(r=>{assert.equal(r.status,200);assert.deepEqual(r.body,responses[0].body);});
  assert.equal(await balance(u),100);
  assert.equal((await db.collection(`economies_v2/${u.localId}/movements`).get()).size,1);
  const again=await call(u,'initialize',{operationId:id()});
  assert.equal(again.body.receipt.code,'already-initialized');assert.equal(await balance(u),100);
});
test('UID isolation, foreign operations and changed parameters cannot cross account boundaries',async()=>{
  const a=await user(),b=await user();const receipt=await initialize(a);await initialize(b);
  assert.equal((await call(b,'getWallet',{expectedOwnerUid:a.localId})).status,403);
  assert.equal((await call(b,'getOperation',{operationId:receipt.operationId})).status,404);
  const collision=await call(a,'purchase',{operationId:receipt.operationId,sku:'sandbox-shirt'});
  assert.equal(collision.status,409);assert.equal(collision.body.error.code,'id-collision');
  assert.equal(await balance(a),100);assert.equal(await balance(b),100);
});
test('simultaneous devices, duplicate claims and purchase preserve ledger, sources and origin',async()=>{
  const u=await user();await initialize(u);const source=await ticket(u),op=id();
  const results=await Promise.all([
    call(u,'claimIncome',{operationId:op,ticketId:source}),call(u,'claimIncome',{operationId:op,ticketId:source}),
    call(u,'purchase',{operationId:id(),sku:'sandbox-shirt'}),call(u,'purchase',{operationId:id(),sku:'sandbox-shirt'}),
  ]);
  results.forEach(r=>assert.equal(r.status,200,JSON.stringify(r.body)));
  assert.deepEqual(results[0],results[1]);assert.equal(await balance(u),120);
  const repeat=await call(u,'claimIncome',{operationId:id(),ticketId:source});
  assert.equal(repeat.body.receipt.status,'declined');assert.equal(repeat.body.receipt.code,'invalid-source');
  const wallet=(await ref(u.localId,'wallet','main').get()).data();assert.equal(wallet.revision,4);
  const movements=(await db.collection(`economies_v2/${u.localId}/movements`).get()).docs.map(s=>s.data()).sort((a,b)=>a.revisionAfter-b.revisionAfter);
  let running=0,previous=null;
  for(const movement of movements) {
    const receipt=(await ref(u.localId,'receipts',movement.operationId).get()).data(),{receiptHash,...financial}=receipt;
    assert.equal(digest(financial),receiptHash);assert.equal(movement.previousHash,previous);
    assert.equal(movement.balanceBefore,running);running+=movement.delta;assert.equal(movement.balanceAfter,running);
    previous=receiptHash;
  }
  assert.equal(running,120);assert.equal(wallet.headHash,previous);
});
test('terminal insufficient-funds receipt remains declined after subsequent credit',async()=>{
  const u=await user();await initialize(u);
  for(let i=0;i<10;i++) assert.equal((await call(u,'purchase',{operationId:id(),sku:'sandbox-shirt'})).body.receipt.status,'committed');
  const operationId=id(),declined=await call(u,'purchase',{operationId,sku:'sandbox-shirt'});
  assert.equal(declined.body.receipt.code,'insufficient-funds');
  const source=await ticket(u);await call(u,'claimIncome',{operationId:id(),ticketId:source});
  assert.deepEqual(await call(u,'purchase',{operationId,sku:'sandbox-shirt'}),declined);
  assert.equal(await balance(u),40);
  assert.equal((await ref(u.localId,'movements',operationId).get()).exists,false);
});
test('before-commit failure writes no financial state; identical retry commits once',async()=>{
  const u=await user();await initialize(u);const operationId=id(),source=await ticket(u);
  await db.doc(`economy_v2_testControls/${u.localId}/faults/${operationId}`).set({mode:'beforeCommit'});
  assert.equal((await call(u,'claimIncome',{operationId,ticketId:source})).status,503);
  assert.equal(await balance(u),100);assert.equal((await ref(u.localId,'receipts',operationId).get()).exists,false);
  assert.equal((await ref(u.localId,'incomeTickets',source).get()).data().consumedBy,undefined);
  assert.equal((await call(u,'claimIncome',{operationId,ticketId:source})).body.receipt.status,'committed');
  assert.equal(await balance(u),140);
});
test('lost response after commit returns uncertainty; recovery and retries never regrant',async()=>{
  const u=await user();await initialize(u);const operationId=id(),source=await ticket(u);
  await db.doc(`economy_v2_testControls/${u.localId}/faults/${operationId}`).set({mode:'afterCommit'});
  const failed=await call(u,'claimIncome',{operationId,ticketId:source});
  assert.equal(failed.status,503);assert.equal(failed.body.error.code,'confirmation-unknown');
  const recovered=await call(u,'getOperation',{operationId});
  assert.equal(recovered.body.receipt.grossPrize,40);
  assert.deepEqual(await call(u,'claimIncome',{operationId,ticketId:source}),recovered);assert.equal(await balance(u),140);
  for(const status of ['seen','skipped','seen']) assert.equal((await call(u,'ackPresentation',{operationId,status})).status,200);
  assert.equal(await balance(u),140);
});
test('client disconnect after confirmed commit can recover without another debit',async()=>{
  const u=await user();await initialize(u);const operationId=id();
  await db.doc(`economy_v2_testControls/${u.localId}/faults/${operationId}`).set({mode:'delayedResponse'});
  const controller=new AbortController();
  const pending=call(u,'purchase',{operationId,sku:'sandbox-shirt'},{signal:controller.signal}).catch(error=>error);
  let exists=false;
  for(let i=0;i<60;i++) {
    exists=(await ref(u.localId,'receipts',operationId).get()).exists;
    if(exists) break;
    await new Promise(r=>setTimeout(r,50));
  }
  assert.equal(exists,true);controller.abort();assert.equal((await pending).name,'AbortError');
  assert.equal((await call(u,'purchase',{operationId,sku:'sandbox-shirt'})).body.receipt.status,'committed');
  assert.equal(await balance(u),90);
});
test('authorized synthetic asset issuance has verifiable origin; forged/missing origin rejected',async()=>{
  const u=await user();await initialize(u);const source=await ticket(u,'sandbox.card.v1'),operationId=id();
  const issued=await call(u,'issueTestAsset',{operationId,ticketId:source});
  assert.equal(issued.body.receipt.status,'committed');const instanceId=issued.body.receipt.result.instanceId;
  assert.equal((await call(u,'getAsset',{instanceId})).status,200);
  assert.equal(await balance(u),100);
  const fake='f'.repeat(64);await ref(u.localId,'inventory',fake).set({instanceId:fake,ownerUid:u.localId,state:'available',originId:id(),verified:true});
  assert.equal((await call(u,'getAsset',{instanceId:fake})).status,409);
  await ref(u.localId,'inventory',instanceId).update({sku:'forged-celestial'});
  assert.equal((await call(u,'getAsset',{instanceId})).status,409);
  assert.equal((await call(u,'issueTestAsset',{operationId:id(),ticketId:source})).body.receipt.status,'declined');
});
test('actual endpoints refuse client amounts, outcomes, arbitrary sources and casino operations',async()=>{
  const u=await user();await initialize(u);
  for(const extra of [{amount:999},{price:0},{grossPrize:999},{stops:[0,0,0,0,0]},{fixture:'maximum'}]) {
    assert.equal((await call(u,'purchase',{operationId:id(),sku:'sandbox-shirt',...extra})).status,400);
  }
  for(const action of ['requestSpin','consumeFreeSpin','importLegacy','transfer']) assert.equal((await call(u,action)).status,400);
  const source=await ticket(u,'client-invented');
  assert.equal((await call(u,'claimIncome',{operationId:id(),ticketId:source})).body.receipt.code,'invalid-source');
  assert.equal(await balance(u),100);
});
test('rules: no direct writes to funds, receipts or tickets, no foreign reads; restore is legacy-only',async()=>{
  const a=await user(),b=await user(),receipt=await initialize(a);
  for(const group of ['wallet','receipts','movements','incomeTickets','inventory','origins','requestLimits']) {
    const path=`economies_v2/${a.localId}/${group}`,key=group==='wallet'?'main':receipt.operationId;
    assert.equal((await rest(a,path,key,'PATCH',{balance:{integerValue:'999'}})).status,403);
    assert.equal((await rest(b,path,key)).status,403);
    assert.equal((await rest(null,path,key)).status,403);
  }
  const privateRead=await rest(a,`economies_v2/${a.localId}/incomeTickets`,'private');assert.equal(privateRead.status,403);
  for(const revision of [1,2]) {
    assert.equal((await rest(a,`players/${a.localId}/progress`,'current','PATCH',{
      revision:{integerValue:String(revision)},payload:{stringValue:JSON.stringify({'rincon.v1':JSON.stringify({coins:999999,cards:{1:999}})})}})).status,200);
  }
  assert.equal(await balance(a),100);
  assert.equal((await db.collection(`economies_v2/${a.localId}/inventory`).get()).empty,true);
});
test('history, bounded requests and per-UID rate limiting operate on real HTTP',async()=>{
  const u=await user(),init=await initialize(u);
  const history=await call(u,'history',{limit:1});assert.equal(history.body.receipts.length,1);
  assert.equal(history.body.receipts[0].operationId,init.operationId);
  assert.equal((await call(u,'history',{limit:51})).status,400);
  const huge=await call(u,'getWallet',{padding:'x'.repeat(9000)});assert.equal(huge.status,413);
  const wrongMethod=await fetch(endpoint+'economyV2');assert.equal(wrongMethod.status,405);
  const minute=String(Math.floor(Date.now()/60000));await ref(u.localId,'requestLimits',minute).set({count:120});
  assert.equal((await call(u,'getWallet')).status,429);
});
after(async()=>{await db.terminate();});
