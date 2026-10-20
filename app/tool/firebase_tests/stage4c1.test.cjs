'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),path=require('node:path'),fs=require('node:fs');
const {createRequire}=require('node:module'),{execFile}=require('node:child_process'),{promisify}=require('node:util');
const deps=createRequire(path.join(__dirname,'../../functions/package.json'));
const {initializeApp,cert}=deps('firebase-admin/app'),{getFirestore}=deps('firebase-admin/firestore'),{getAuth}=deps('firebase-admin/auth');
const {getConfig,evaluateStops,rulesHash}=require('../../functions/economy_v2/casino/engine.cjs');
const {rngContext,emptyState}=require('../../functions/economy_v2/casino/service.cjs');
const {createRandom}=require('../../functions/economy_v2/casino/rng.cjs');
const {digest}=require('../../functions/economy_v2/common.cjs');
const project='demo-lucky-readiness',id=()=>crypto.randomBytes(16).toString('hex');
assert.equal(process.env.GCLOUD_PROJECT,project);assert.equal(process.versions.node.split('.')[0],'22');
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'])assert.match(process.env[name]||'',/^127\.0\.0\.1:\d+$/);
const key=crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
const app=initializeApp({projectId:project,credential:cert({projectId:project,clientEmail:`fixture@${project}.iam.gserviceaccount.com`,privateKey:key})});
const db=getFirestore(app),auth=getAuth(app),ref=(uid,g,n)=>db.doc(`economies_v2/${uid}/${g}/${n}`);
const endpoint=`http://127.0.0.1:15001/${project}/us-central1/economyV2`;
const policy=db.doc('economy_v2_server/casino');
const defaults={enabledConfigs:['reference25','scaled10'],currentEpoch:'sandbox-epoch-1'};
const secrets=JSON.parse(fs.readFileSync(path.join(__dirname,'../../build/lucky-stage4a/functions/casino-keys.local.json'),'utf8'));
async function authCall(action,body){const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:${action}?key=fake`,{
  method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(response.status,200);return response.json();}
async function user(){
  const email=`${id()}@example.invalid`,password='local-test-password-only';
  const created=await authCall('signUp',{email,password,returnSecureToken:true});
  await auth.setCustomUserClaims(created.localId,{economySandbox:true});
  const u=await authCall('signInWithPassword',{email,password,returnSecureToken:true});
  const init=await call(u,'initialize',{operationId:id()});assert.equal(init.body.receipt.status,'committed');return u;
}
async function call(u,action,params={},options={}){
  const response=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${u.idToken}`},
    body:JSON.stringify({action,expectedOwnerUid:u.localId,...params}),...(options.signal?{signal:options.signal}:{})});
  return {status:response.status,body:await response.json()};
}
async function state(u){const s=await ref(u.localId,'casinoState','lucky777').get();return s.exists?s.data():emptyState();}
async function wallet(u){return (await call(u,'getWallet')).body.wallet;}
const paid=(sequence=0,configId='reference25')=>({operationId:id(),sequence,configId});
const financial=response=>{assert.equal(response.status,200,JSON.stringify(response.body));return response.body.receipt;};
test('4C2 browser demo permits private preflight and rejects a public POST origin',async()=>{
  for(const origin of ['http://127.0.0.1:8091','http://192.168.1.20:8091']){
    const r=await fetch(endpoint,{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,content-type'}});
    assert.equal(r.headers.get('access-control-allow-origin'),origin);
  }
  const denied=await fetch(endpoint,{method:'POST',headers:{Origin:'https://example.com','Content-Type':'application/json'},body:'{}'});
  assert.equal(denied.status,403);assert.equal((await denied.json()).error.code,'invalid-demo-origin');
});
test('4C2 presentation recovery is owner scoped and leaves default receipt shape immutable',async()=>{
  const u=await user(),v=await user();
  const r=financial(await call(u,'requestSpin',paid()));
  assert.equal((await call(u,'getOperation',{operationId:r.operationId,includePresentation:true})).body.presentation,'pending');
  await call(u,'ackPresentation',{operationId:r.operationId,status:'seen'});
  const recovered=await call(u,'getOperation',{operationId:r.operationId,includePresentation:true});
  assert.deepEqual(recovered.body.receipt,r);assert.equal(recovered.body.presentation,'seen');
  assert.deepEqual((await call(u,'getOperation',{operationId:r.operationId})).body,{receipt:r});
  const history=await call(u,'history',{limit:50,includePresentation:true});
  assert.equal(history.body.presentations[r.operationId],'seen');
  assert.equal((await call(v,'getOperation',{operationId:r.operationId,includePresentation:true})).status,404);
  assert.equal((await call(u,'history',{includePresentation:'true'})).status,400);
});
async function audit(u){
  const docs=(await db.collection(`economies_v2/${u.localId}/movements`).get()).docs.map(d=>d.data()).sort((a,b)=>a.revisionAfter-b.revisionAfter);
  let amount=0,head=null,revision=0;
  for(const m of docs){
    assert.equal(m.revisionBefore,revision);assert.equal(m.previousHash,head);assert.equal(m.balanceBefore,amount);
    const r=(await ref(u.localId,'receipts',m.operationId).get()).data(),{receiptHash,...data}=r;
    assert.equal(digest(data),receiptHash);assert.equal(r.status,'committed');assert.equal(r.netDelta,m.delta);
    amount+=m.delta;revision++;head=receiptHash;assert.equal(m.balanceAfter,amount);
    if(['requestSpin','consumeFreeSpin'].includes(r.action)){
      const stored=(await ref(u.localId,'casinoRounds',m.operationId).get()).data();assert.deepEqual(stored,r.result);
      assert.equal(stored.round.grid.length,15);assert.equal(r.grossPrize,stored.round.amount);
      assert.deepEqual(evaluateStops(stored.round.stops,getConfig(stored.configId),stored.bonusBefore||{remaining:0,awarded:0}),stored.round);
    }
  }
  const w=await wallet(u);assert.equal(w.balance,amount);assert.equal(w.revision,revision);assert.equal(w.headHash,head);
}
// Rare-event fixtures are found using private synthetic test keys, never by an
// outcome/stop override. HTTP still calls the real RNG and engine. No such oracle
// is exported. This makes retrigger/cap tests deterministic and reproducible.
async function selected(u,predicate,configId='reference25'){
  const s=await state(u),p=(await policy.get()).data()||defaults,free=!!s.bonus;
  const config=free?s.bonus.configId:configId,rules=getConfig(config),epoch=free?s.bonus.keyEpoch:p.currentEpoch;
  for(let n=0;n<200000;n++){
    const input={operationId:id(),sequence:s.sequence,...(!free?{configId:config}:{})};
    const action=free?'consumeFreeSpin':'requestSpin';
    const intent={rulesVersion:rules.rulesVersion,rulesHash:rulesHash(rules),referenceStake:rules.lineStake*5,
      bonusId:free?s.bonus.bonusId:input.operationId,keyEpoch:epoch};
    const random=createRandom(Buffer.from(secrets[epoch],'hex'),rngContext(u.localId,{...input,action},intent));
    const round=evaluateStops(rules.reels.map(r=>random.nextInt(r.length)),rules,free?s.bonus:{remaining:0,awarded:0});
    if(predicate(round))return {input,round,action};
  }
  throw Error('synthetic-key search exhausted');
}
test('paid authentic server spins: 25/10, complete round, wallet and presentation committed together',async()=>{
  for(const configId of ['reference25','scaled10']){
    const u=await user(),choice=await selected(u,r=>r.scatterColumns.length<3,configId);
    const receipt=financial(await call(u,'requestSpin',choice.input));
    assert.equal(receipt.status,'committed');assert.deepEqual(receipt.result.round,choice.round);
    assert.equal(receipt.chargedCost,configId==='reference25'?25:10);assert.equal(receipt.result.sequenceAfter,1);
    assert.equal((await ref(u.localId,'presentation',choice.input.operationId).get()).data().status,'pending');
    assert.equal((await wallet(u)).balance,100-receipt.chargedCost+receipt.grossPrize);await audit(u);
  }
});
test('insufficient funds creates immutable terminal decline, no debit, result or nonce change',async()=>{
  const u=await user();await ref(u.localId,'wallet','main').update({balance:0});
  const input=paid(),response=await call(u,'requestSpin',input),r=financial(response);
  assert.equal(r.code,'insufficient-funds');assert.equal(r.chargedCost,0);
  assert.equal((await ref(u.localId,'casinoRounds',input.operationId).get()).exists,false);assert.equal((await state(u)).sequence,0);
  await ref(u.localId,'wallet','main').update({balance:100});assert.deepEqual(await call(u,'requestSpin',input),response);
});
test('same ID from concurrent devices yields identical result and one financial movement',async()=>{
  const u=await user(),input=paid(),responses=await Promise.all(Array.from({length:5},()=>call(u,'requestSpin',input)));
  responses.forEach(r=>assert.deepEqual(r,responses[0]));assert.equal(financial(responses[0]).status,'committed');
  assert.equal((await db.collection(`economies_v2/${u.localId}/casinoRounds`).get()).size,1);await audit(u);
});
test('different IDs on the same nonce commit one round; changed parameters on a used ID fail',async()=>{
  const u=await user(),a=paid(),b=paid();
  const responses=await Promise.all([call(u,'requestSpin',a),call(u,'requestSpin',b)]);
  const receipts=responses.map(financial);assert.equal(receipts.filter(r=>r.status==='committed').length,1);
  assert.equal(receipts.find(r=>r.status==='declined').code,'stale-sequence');
  assert.equal((await call(u,'requestSpin',{...a,configId:'scaled10'})).status,409);await audit(u);
});
test('failure before commit persists private intention; key rotation/restarted service retains same outcome',async()=>{
  const u=await user(),input=paid();
  await db.doc(`economy_v2_testControls/${u.localId}/faults/${input.operationId}`).set({mode:'beforeCommit'});
  assert.equal((await call(u,'requestSpin',input)).status,503);
  assert.equal((await ref(u.localId,'receipts',input.operationId).get()).exists,false);assert.equal((await wallet(u)).balance,100);
  const intent=(await ref(u.localId,'casinoIntents',input.operationId).get()).data();assert.equal(intent.keyEpoch,'sandbox-epoch-1');
  const originalRandom=createRandom(Buffer.from(secrets[intent.keyEpoch],'hex'),rngContext(u.localId,{...input,action:'requestSpin'},intent));
  const originalRound=evaluateStops(getConfig(intent.configId).reels.map(r=>originalRandom.nextInt(r.length)),getConfig(intent.configId));
  await policy.set({enabledConfigs:['scaled10'],currentEpoch:'sandbox-epoch-2'});
  // A new process reconstructs the service, keyring and DB client; no RNG cache.
  const code=`
    const deps=require('module').createRequire(process.argv[1]+'/functions/package.json');
    const {initializeApp,cert}=deps('firebase-admin/app'),{getFirestore}=deps('firebase-admin/firestore');
    const k=require('crypto').generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
    initializeApp({projectId:'demo-lucky-readiness',credential:cert({projectId:'demo-lucky-readiness',clientEmail:'restart@demo-lucky-readiness.iam.gserviceaccount.com',privateKey:k})});
    const db=getFirestore(),secret=JSON.parse(require('fs').readFileSync(process.argv[1]+'/build/lucky-stage4a/functions/casino-keys.local.json','utf8'));
    const {createCasinoService}=require(process.argv[1]+'/functions/economy_v2/casino/service.cjs');
    const service=createCasinoService({db,currentEpoch:'sandbox-epoch-2',keyring:Object.fromEntries(Object.entries(secret).map(([k,v])=>[k,Buffer.from(v,'hex')]))});
    service.run(process.argv[2],JSON.parse(process.argv[3])).then(async r=>{console.log(JSON.stringify(r));await db.terminate();}).catch(e=>{console.error(e);process.exitCode=1;});`;
  const child=await promisify(execFile)(process.execPath,['-e',code,path.resolve(__dirname,'../..'),u.localId,JSON.stringify({...input,action:'requestSpin',expectedOwnerUid:u.localId})]);
  const restarted=JSON.parse(child.stdout),recovered=await call(u,'getOperation',{operationId:input.operationId});
  assert.deepEqual(recovered.body,restarted);assert.equal(recovered.body.receipt.result.keyEpoch,'sandbox-epoch-1');
  assert.deepEqual(recovered.body.receipt.result.round,originalRound);
  assert.deepEqual((await call(u,'requestSpin',input)).body,restarted);await audit(u);await policy.set(defaults);
});
test('lost HTTP response after commit recovers exact stored result with no second charge',async()=>{
  const u=await user(),input=paid();await db.doc(`economy_v2_testControls/${u.localId}/faults/${input.operationId}`).set({mode:'afterCommit'});
  assert.equal((await call(u,'requestSpin',input)).status,503);
  const stored=await call(u,'getOperation',{operationId:input.operationId});assert.equal(financial(stored).status,'committed');
  assert.deepEqual(await call(u,'requestSpin',input),stored);await audit(u);
});
test('Firestore SDK retries ABORTED callback without changing RNG or committing twice',async()=>{
  const u=await user(),input=paid(),fault=db.doc(`economy_v2_testControls/${u.localId}/faults/${input.operationId}`);
  await fault.set({mode:'retryTransaction'});
  assert.equal(financial(await call(u,'requestSpin',input)).status,'committed');
  assert.ok((await fault.get()).data().attempts>=2);await audit(u);
});
test('in-flight account switch and actual HTTP disconnect cannot duplicate or redirect a round',async()=>{
  const a=await user(),b=await user(),input=paid(),controller=new AbortController();
  await db.doc(`economy_v2_testControls/${a.localId}/faults/${input.operationId}`).set({mode:'delayedResponse'});
  const pending=call(a,'requestSpin',input,{signal:controller.signal}).catch(error=>error);
  let exists=false;
  for(let i=0;i<60;i++){
    exists=(await ref(a.localId,'receipts',input.operationId).get()).exists;
    if(exists)break;await new Promise(resolve=>setTimeout(resolve,50));
  }
  assert.equal(exists,true);
  assert.equal((await call(b,'requestSpin',{...input,expectedOwnerUid:a.localId})).status,403);
  assert.equal((await call(b,'getOperation',{operationId:input.operationId})).status,404);assert.equal((await wallet(b)).balance,100);
  controller.abort();assert.equal((await pending).name,'AbortError');
  const recovered=await call(a,'getOperation',{operationId:input.operationId});
  assert.equal(financial(recovered).status,'committed');assert.deepEqual(await call(a,'requestSpin',input),recovered);await audit(a);
});
test('real retriggers: exactly 50 awarded/consumed, pinned rules/epoch, session renewal and retired recovery',async()=>{
  const u=await user();let choice=await selected(u,r=>r.scatterColumns.length===5);
  const first=financial(await call(u,choice.action,choice.input));assert.equal(first.result.round.grantedSpins,12);
  await policy.set({enabledConfigs:['scaled10'],currentEpoch:'sandbox-epoch-2'});
  assert.equal(financial(await call(u,'requestSpin',paid(1,'scaled10'))).code,'bonus-active');
  assert.equal((await call(u,'consumeFreeSpin',{operationId:id(),sequence:1,configId:'scaled10'})).status,400);
  const refreshed=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/securetoken.googleapis.com/v1/token?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:u.refreshToken})});
  assert.equal(refreshed.status,200);u.idToken=(await refreshed.json()).id_token;
  let consumed=0,granted=12;
  while((await state(u)).bonus){
    const s=await state(u);
    choice=s.bonus.awarded<50?await selected(u,r=>r.scatterColumns.length===5):{action:'consumeFreeSpin',input:{operationId:id(),sequence:s.sequence}};
    let response;
    if(consumed===0){
      const child=await promisify(execFile)(process.execPath,['-e',`
        async function call(body){const r=await fetch(process.env.DEMO_ENDPOINT,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+process.env.DEMO_TOKEN},body:JSON.stringify(body)});return {status:r.status,body:await r.json()};}
        (async()=>{const input=JSON.parse(process.env.DEMO_REQUEST);const recovered=await call({action:'getCasinoState',expectedOwnerUid:input.expectedOwnerUid});
          if(recovered.status!==200||!recovered.body.state.bonus)throw Error('missing recovered bonus');
          input.sequence=recovered.body.state.sequence;console.log(JSON.stringify(await call(input)));})().catch(e=>{console.error(e.message);process.exitCode=1;});
      `],{env:{...process.env,DEMO_ENDPOINT:endpoint,DEMO_TOKEN:u.idToken,DEMO_REQUEST:JSON.stringify({action:choice.action,expectedOwnerUid:u.localId,...choice.input})}});
      response=JSON.parse(child.stdout);
    } else response=await call(u,choice.action,choice.input);
    const r=financial(response);assert.equal(r.status,'committed');
    assert.equal(r.chargedCost,0);assert.equal(r.result.configId,'reference25');assert.equal(r.result.keyEpoch,'sandbox-epoch-1');
    granted+=r.result.round.grantedSpins;consumed++;assert.ok(granted<=50);assert.ok(consumed<=50);
    if(consumed===1)assert.deepEqual(await call(u,'consumeFreeSpin',choice.input),{status:200,body:{receipt:r}});
  }
  assert.equal(consumed,50);assert.equal(granted,50);assert.equal((await state(u)).sequence,51);
  assert.equal(financial(await call(u,'consumeFreeSpin',{operationId:id(),sequence:51})).code,'bonus-not-active');
  assert.equal(financial(await call(u,'requestSpin',paid(51))).code,'config-not-authorized');
  assert.deepEqual((await call(u,'getOperation',{operationId:first.operationId})).body.receipt,first);
  assert.equal(financial(await call(u,'requestSpin',paid(51,'scaled10'))).result.keyEpoch,'sandbox-epoch-2');
  await audit(u);await policy.set(defaults);
});
test('client cannot choose stops, payouts, price, RNG epoch, rules or read private intentions',async()=>{
  const u=await user();for(const patch of [{stops:[0,0,0,0,0]},{prize:999},{price:1},{keyEpoch:'sandbox-epoch-2'},{rulesVersion:'other'}])
    assert.equal((await call(u,'requestSpin',{...paid(),...patch})).status,400);
  assert.equal(financial(await call(u,'requestSpin',paid(0,'unauthorized'))).code,'config-not-authorized');
  const input=paid();await call(u,'requestSpin',input);
  const host=process.env.FIRESTORE_EMULATOR_HOST;
  for(const g of ['casinoIntents','incomeTickets']){
    const response=await fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/economies_v2/${u.localId}/${g}/${input.operationId}`,{headers:{Authorization:`Bearer ${u.idToken}`}});
    assert.equal(response.status,403);
  }
  const publicData=JSON.stringify((await call(u,'getOperation',{operationId:input.operationId})).body);
  for(const secret of Object.values(secrets))assert.ok(!publicData.includes(secret));
  assert.doesNotMatch(publicData,/"(seed|keyring|root|privateKey)"/);
});
test('missing archived bonus hash fails without repricing, consuming a free spin or granting a reward',async()=>{
  const u=await user(),choice=await selected(u,r=>r.scatterColumns.length>=3);
  assert.equal(financial(await call(u,'requestSpin',choice.input)).status,'committed');
  const saved=await state(u),before=await wallet(u);
  await ref(u.localId,'casinoState','lucky777').set({...saved,bonus:{...saved.bonus,rulesHash:'archive-missing'}});
  const input={operationId:id(),sequence:saved.sequence},response=await call(u,'consumeFreeSpin',input);
  assert.equal(response.status,503);assert.equal(response.body.error.code,'archived-config-unavailable');
  assert.deepEqual(await wallet(u),before);
  assert.equal((await state(u)).bonus.remaining,saved.bonus.remaining);
  assert.equal((await ref(u.localId,'receipts',input.operationId).get()).exists,false);
});
test('legacy restores remain unchanged and cannot replace synthetic wallet or real round receipts',async()=>{
  const u=await user(),input=paid();const r=financial(await call(u,'requestSpin',input)),before=await wallet(u);
  const host=process.env.FIRESTORE_EMULATOR_HOST;
  for(const revision of [1,2]){
    const fields={revision:{integerValue:String(revision)},payload:{stringValue:JSON.stringify({'rincon.v1':JSON.stringify({coins:900000})})}};
    const response=await fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/players/${u.localId}/progress/current`,{
      method:'PATCH',headers:{Authorization:`Bearer ${u.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({fields})});
    assert.equal(response.status,200);
  }
  assert.deepEqual(await wallet(u),before);assert.deepEqual(financial(await call(u,'getOperation',{operationId:input.operationId})),r);
});
after(async()=>{await policy.set(defaults);await db.terminate();});
