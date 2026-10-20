'use strict';
// Test-only oracle for a reproducible server Scatter; never exported by service.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{createRequire}=require('node:module');
const deps=createRequire(path.join(__dirname,'../../functions/package.json'));
const {initializeApp,cert}=deps('firebase-admin/app'),{getAuth}=deps('firebase-admin/auth');
const {getConfig,evaluateStops,rulesHash}=require('../../functions/economy_v2/casino/engine.cjs');
const {rngContext,emptyState}=require('../../functions/economy_v2/casino/service.cjs');
const {createRandom}=require('../../functions/economy_v2/casino/rng.cjs');
const assert=require('node:assert/strict');
const project='demo-lucky-readiness';assert.equal(process.env.GCLOUD_PROJECT,project);
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'])assert.match(process.env[name]||'',/^127\.0\.0\.1:\d+$/);
const privateKey=crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
initializeApp({projectId:project,credential:cert({projectId:project,clientEmail:`fixture@${project}.iam.gserviceaccount.com`,privateKey})});
async function main(){
 const email=`flutter-${crypto.randomBytes(8).toString('hex')}@example.invalid`,password='local-test-password-only';
 async function auth(action){const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:${action}?key=fake`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});assert.equal(r.status,200);return r.json();}
 const account=await auth('signUp');await getAuth().setCustomUserClaims(account.localId,{economySandbox:true});const user=await auth('signInWithPassword');
 const endpoint=`http://127.0.0.1:15001/${project}/us-central1/economyV2`;
 const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${user.idToken}`},body:JSON.stringify({action:'initialize',expectedOwnerUid:user.localId,operationId:crypto.randomBytes(16).toString('hex')})});assert.equal(r.status,200);
 const rules=getConfig('reference25'),epoch='sandbox-epoch-1',state=emptyState();
 const secrets=JSON.parse(fs.readFileSync(path.join(__dirname,'../../build/lucky-stage4a/functions/casino-keys.local.json'),'utf8'));
 let intent;
 for(let n=0;n<200000;n++){
   const operationId=crypto.randomBytes(16).toString('hex');
   const pinned={rulesVersion:rules.rulesVersion,rulesHash:rulesHash(rules),referenceStake:25,bonusId:operationId,keyEpoch:epoch};
   const rng=createRandom(Buffer.from(secrets[epoch],'hex'),rngContext(user.localId,{action:'requestSpin',operationId,sequence:state.sequence,configId:'reference25'},pinned));
   const round=evaluateStops(rules.reels.map(reel=>rng.nextInt(reel.length)),rules,{remaining:0,awarded:0});
   if(round.grantedSpins>0){intent={id:operationId,origin:'sandbox',ownerUid:user.localId,sequence:0,configId:'reference25',free:false};break;}
 }
 assert.ok(intent);
 fs.writeFileSync(path.join(__dirname,'../../build/lucky-stage4a/client-fixture.json'),JSON.stringify({uid:user.localId,token:user.idToken,endpoint,intent}));
 console.log('Isolated Flutter HTTP fixture ready (synthetic credentials kept in ignored build directory).');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
