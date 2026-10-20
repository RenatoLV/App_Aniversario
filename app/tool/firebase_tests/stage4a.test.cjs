'use strict';
const {test,after}=require('node:test'), assert=require('node:assert/strict');
const {promisify}=require('node:util'), {execFile}=require('node:child_process');
const execFileAsync=promisify(execFile);
const {db,project,ref,seed,operate,transferVerified}=require('./stage4a-harness.cjs');
const host=process.env.FIRESTORE_EMULATOR_HOST, auth=process.env.FIREBASE_AUTH_EMULATOR_HOST;
let counter=0;
const id=()=> (++counter).toString(16).padStart(32,'0');
async function user() {
  const response=await fetch(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});
  assert.equal(response.status,200);return response.json();
}
async function rest(actor,path,method='GET',fields) {
  const headers={'Content-Type':'application/json'};
  if(actor) headers.Authorization=`Bearer ${actor.idToken}`;
  return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/${path}`,{
    method,headers,...(fields?{body:JSON.stringify({fields})}:{})});
}
const paid=uid=>({id:id(),expectedOwnerUid:uid,kind:'paid',sequence:0});
const balance=async uid=>(await ref(uid,'wallet','main').get()).data().balance;

test('rules: owner-only reads; unauthenticated and other account denied; all client V2 writes denied',async()=>{
  const a=await user(), b=await user(), uid=a.localId;
  await seed(uid);
  const groups=['wallet','movements','receipts','casinoRounds','casinoState','inventory','origins','compatibility','presentation'];
  for(const group of groups) {
    const key=group==='wallet'?'main':group==='casinoState'?'lucky777':'fixture';
    await ref(uid,group,key).set({ownerUid:uid});
    const path=`economies_v2/${uid}/${group}/${key}`;
    assert.equal((await rest(a,path)).status,200,group);
    assert.equal((await rest(b,path)).status,403,group);
    assert.equal((await rest(null,path)).status,403,group);
    for(const method of ['PATCH','DELETE']) {
      assert.equal((await rest(a,path,method,method==='PATCH'?{balance:{integerValue:'999999'}}:null)).status,403,group);
    }
    assert.equal((await rest(a,`economies_v2/${uid}/${group}/new`,'PATCH',{x:{integerValue:'1'}})).status,403);
    assert.equal((await rest(a,`economies_v2/${uid}/${group}`)).status,200,'own collection list');
    assert.equal((await rest(b,`economies_v2/${uid}/${group}`)).status,403,'foreign collection list');
    assert.equal((await rest(null,`economies_v2/${uid}/${group}`)).status,403,'unauthenticated collection list');
  }
  await ref(uid,'incomeTickets','private').set({amount:100});
  assert.equal((await rest(a,`economies_v2/${uid}/incomeTickets/private`)).status,403);
});
test('Firestore transaction: duplicate taps and requests return a single receipt and movement',async()=>{
  const {localId:uid}=await user();await seed(uid);const input=paid(uid);
  const results=await Promise.all(Array.from({length:6},()=>operate(uid,input)));
  results.forEach(r=>assert.deepEqual(r,results[0]));
  assert.equal(await balance(uid),95);
  assert.equal((await db.collection(`economies_v2/${uid}/movements`).get()).size,1);
});
test('Firestore contention: two devices, different IDs, same casino sequence accept one intention',async()=>{
  const {localId:uid}=await user();await seed(uid);
  const results=await Promise.allSettled([operate(uid,paid(uid)),operate(uid,paid(uid))]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
  assert.match(results.find(x=>x.status==='rejected').reason.message,/stale-sequence/);
  assert.equal(await balance(uid),95);
});
test('UID namespaces and late account switch do not charge the wrong owner',async()=>{
  const a=await user(),b=await user();await seed(a.localId);await seed(b.localId);
  const input=paid(a.localId);
  await assert.rejects(operate(b.localId,input),/account-changed/);
  await assert.rejects(operate(null,input),/unauthenticated/);
  await operate(a.localId,input);
  await operate(b.localId,{...input,expectedOwnerUid:b.localId});
  assert.equal(await balance(a.localId),95);assert.equal(await balance(b.localId),95);
});
test('failure before commit writes neither charge, receipt nor bonus',async()=>{
  const {localId:uid}=await user();await seed(uid);const input=paid(uid);
  await assert.rejects(operate(uid,input,'beforeCommit'),/before-commit/);
  assert.equal(await balance(uid),100);
  assert.equal((await ref(uid,'receipts',input.id).get()).exists,false);
  assert.equal((await ref(uid,'casinoState','lucky777').get()).data().remaining,0);
  await operate(uid,input);assert.equal(await balance(uid),95);
});
test('response lost after commit: recover stored receipt and retry without crediting twice',async()=>{
  const {localId:uid}=await user();await seed(uid);const input=paid(uid);
  await assert.rejects(operate(uid,input,'afterCommit'),/lost-response/);
  const recovered=(await ref(uid,'receipts',input.id).get()).data();
  assert.deepEqual(await operate(uid,input),recovered);assert.equal(await balance(uid),95);
  await assert.rejects(operate(uid,{...input,kind:'free'}),/id-collision/);
});
test('simultaneous purchase and legitimate test-server reward preserve both writes',async()=>{
  const {localId:uid}=await user();await seed(uid);
  await ref(uid,'incomeTickets','match-one').set({ownerUid:uid,used:false,amount:40});
  const purchase={id:id(),expectedOwnerUid:uid,kind:'purchase',sku:'test-shirt'};
  const income={id:id(),expectedOwnerUid:uid,kind:'income',ticketId:'match-one'};
  await Promise.all([operate(uid,purchase),operate(uid,income)]);
  assert.equal(await balance(uid),130);
  assert.equal((await ref(uid,'wallet','main').get()).data().revision,2);
  assert.equal((await ref(uid,'inventory','test-shirt').get()).data().verified,true);
  await assert.rejects(operate(uid,{...income,id:id()}),/invalid-ticket/);
  assert.equal(await balance(uid),130);
});
test('client cannot choose monetary amounts, outcomes or reward tickets belonging to another user',async()=>{
  const a=await user(),b=await user();await seed(a.localId);await seed(b.localId);
  await ref(a.localId,'incomeTickets','foreign').set({ownerUid:b.localId,used:false,amount:999});
  for(const extra of [{amount:999},{gross:999},{stops:[0,0,0,0,0]},{balance:999}]) {
    await assert.rejects(operate(a.localId,{...paid(a.localId),...extra}),/economic-input/);
  }
  await assert.rejects(operate(a.localId,{id:id(),expectedOwnerUid:a.localId,kind:'income',ticketId:'foreign'}),/invalid-ticket/);
  assert.equal(await balance(a.localId),100);
});
test('legacy restoration preserves history but cannot overwrite or promote verified funds',async()=>{
  const a=await user(),uid=a.localId;await seed(uid);
  for(const revision of [1,2]) {
    const response=await rest(a,`players/${uid}/progress/current`,'PATCH',{
      revision:{integerValue:String(revision)},payload:{stringValue:JSON.stringify({'rincon.v1':JSON.stringify({coins:1000000,cardVariants:{'10000:celestial:gold':1}})})}});
    assert.equal(response.status,200,await response.text());
  }
  assert.equal(await balance(uid),100);
  assert.equal((await db.collection(`economies_v2/${uid}/inventory`).get()).empty,true);
  assert.equal((await ref(uid,'compatibility','current').get()).data().legacyPromoted,false);
});
test('provenance boundary refuses legacy/missing origin; verified test purchase can transfer once',async()=>{
  const a=await user(),b=await user();await seed(a.localId);await seed(b.localId);
  await assert.rejects(transferVerified(a.localId,b.localId,'legacy-card',id()),/unverified-origin/);
  await ref(a.localId,'inventory','forged').set({ownerUid:a.localId,verified:true,originId:id()});
  await assert.rejects(transferVerified(a.localId,b.localId,'forged',id()),/unverified-origin/);
  await operate(a.localId,{id:id(),expectedOwnerUid:a.localId,kind:'purchase',sku:'test-shirt'});
  await transferVerified(a.localId,b.localId,'test-shirt',id());
  await assert.rejects(transferVerified(a.localId,b.localId,'test-shirt',id()),/unverified-origin/);
  assert.equal((await ref(b.localId,'inventory','test-shirt').get()).data().ownerUid,b.localId);
});
test('new authenticated session recovers persisted free spins; consumes once without charge',async()=>{
  const a=await user(),uid=a.localId;await seed(uid);await operate(uid,paid(uid));
  const refresh=await fetch(`http://${auth}/securetoken.googleapis.com/v1/token?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({grant_type:'refresh_token',refresh_token:a.refreshToken})});
  assert.equal(refresh.status,200);const token=await refresh.json();
  const response=await rest({idToken:token.id_token},`economies_v2/${uid}/casinoState/lucky777`);
  assert.equal(response.status,200);
  assert.equal((await response.json()).fields.remaining.integerValue,'12');
  const free={id:id(),expectedOwnerUid:uid,kind:'free',sequence:1};
  // A new Node client process has no in-memory bonus or receipt cache.
  const child=await execFileAsync(process.execPath,['-e',`
    const {operate,db}=require(process.argv[1]);
    operate(process.argv[2],JSON.parse(process.argv[3])).then(async result=>{
      console.log(JSON.stringify(result));await db.terminate();
    }).catch(error=>{console.error(error);process.exitCode=1;});
  `,require.resolve('./stage4a-harness.cjs'),uid,JSON.stringify(free)]);
  const result=JSON.parse(child.stdout);await operate(uid,free);
  assert.equal(result.cost,0);assert.equal(await balance(uid),95);
  assert.equal((await ref(uid,'casinoState','lucky777').get()).data().remaining,11);
  await ref(uid,'presentation',free.id).set({status:'seen'});
  assert.equal(await balance(uid),95);
});
after(async()=>{await db.terminate();});
