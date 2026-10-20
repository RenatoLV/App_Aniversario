'use strict';
// Backend-only demo; all requests use the authentic HTTP service. No UI/legacy.
const assert=require('node:assert/strict'),crypto=require('node:crypto'),{createRequire}=require('node:module');
const deps=createRequire(require('node:path').join(__dirname,'../functions/package.json'));
const {initializeApp,cert}=deps('firebase-admin/app'),{getAuth}=deps('firebase-admin/auth');
const project='demo-lucky-readiness',id=()=>crypto.randomBytes(16).toString('hex');
assert.equal(process.env.GCLOUD_PROJECT,project);
for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'])assert.match(process.env[key]||'',/^127\.0\.0\.1:\d+$/);
const key=crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
initializeApp({projectId:project,credential:cert({projectId:project,clientEmail:`demo@${project}.iam.gserviceaccount.com`,privateKey:key})});
async function main(){
  const seedOnly=process.argv.includes('--seed-only');
  const email=seedOnly?'lucky.player@example.invalid':`${id()}@example.invalid`,password='local-demo-password-only';
  async function authCall(action,body){const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:${action}?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(r.status,200);return r.json();}
  let account;
  if(seedOnly){
    try{account={localId:(await getAuth().getUserByEmail(email)).uid};}
    catch(error){if(error.code!=='auth/user-not-found')throw error;account=await authCall('signUp',{email,password,returnSecureToken:true});}
  }else account=await authCall('signUp',{email,password,returnSecureToken:true});
  await getAuth().setCustomUserClaims(account.localId,{economySandbox:true});
  const user=await authCall('signInWithPassword',{email,password,returnSecureToken:true});
  async function call(action,params={}){
    const body=JSON.stringify({action,expectedOwnerUid:user.localId,...params});
    for(let attempt=0;attempt<4;attempt++){
      const r=await fetch(`http://127.0.0.1:15001/${project}/us-central1/economyV2`,{
        method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${user.idToken}`},body});
      const data=await r.json();
      if(r.status===429){await new Promise(resolve=>setTimeout(resolve,60050-Date.now()%60000));continue;}
      if(r.status===503){await new Promise(resolve=>setTimeout(resolve,250));continue;}
      assert.equal(r.status,200,JSON.stringify(data));return data;
    }
    throw Error(`Confirmacion pendiente; conservar la misma peticion: ${action} ${params.operationId||''}`);
  }
  if(!(await call('getWallet')).wallet)await call('initialize',{operationId:id()});
  if(seedOnly){console.log('Sandbox listo: lucky.player@example.invalid / local-demo-password-only. Saldo existente conservado.');return;}
  console.log('DEMO local: 100 monedas sinteticas, sin saldo historico ni produccion.');
  for(const configId of ['reference25','scaled10']){
    let state=(await call('getCasinoState')).state;
    let response=await call('requestSpin',{operationId:id(),sequence:state.sequence,configId});
    for(let count=0;;count++){
      const r=response.receipt;
      console.log(JSON.stringify({operationId:r.operationId,status:r.status,coste:r.chargedCost,premio:r.grossPrize,
        neto:r.netDelta,saldo:r.balanceAfter,gratisPendientes:r.result.bonusAfter?.remaining||0,casillas:r.result.round?.grid}));
      const recovered=await call('getOperation',{operationId:r.operationId});assert.deepEqual(recovered,response);
      await call('ackPresentation',{operationId:r.operationId,status:'seen'});
      state=(await call('getCasinoState')).state;
      if(!state.bonus)break;
      assert.ok(count<50);response=await call('consumeFreeSpin',{operationId:id(),sequence:state.sequence});
    }
  }
  console.log(JSON.stringify({carteraFinal:(await call('getWallet')).wallet}));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
