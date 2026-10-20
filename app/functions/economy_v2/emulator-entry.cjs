'use strict';
// Dedicated entrypoint copied into an ignored Functions sandbox by the test runner.
// It must never be used as the production Functions entrypoint.
const assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const {onRequest}=require('firebase-functions/v2/https');
const {initializeApp,cert}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
const {getAppCheck}=require('firebase-admin/app-check');
const {createEconomyHandler}=require('./http.cjs');
const {decodeKeyring}=require('./casino/keys.cjs');
assert.equal(process.env.GCLOUD_PROJECT,'demo-lucky-readiness');
assert.equal(process.env.FUNCTIONS_EMULATOR,'true');
// Binding the demo to a private LAN must not send Admin SDK traffic to 0.0.0.0.
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) {
  if(/^0\.0\.0\.0:\d+$/.test(process.env[name]||''))process.env[name]=process.env[name].replace('0.0.0.0:','127.0.0.1:');
}
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) assert.match(process.env[name]||'',/^127\.0\.0\.1:\d+$/);
const privateKey=crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
initializeApp({projectId:'demo-lucky-readiness',credential:cert({projectId:'demo-lucky-readiness',
  clientEmail:'emulator@demo-lucky-readiness.iam.gserviceaccount.com',privateKey})});
const casinoOptions=decodeKeyring(fs.readFileSync(path.join(__dirname,'casino-keys.local.json'),'utf8'),'sandbox-epoch-1');
const shared={db:getFirestore(),auth:getAuth(),appCheck:getAppCheck(),syntheticEnabled:true,casinoOptions};
// Browser demo only: CORS never allows production origins or arbitrary domains.
const options={region:'us-central1',cors:[/^http:\/\/(localhost|127\.0\.0\.1|10\.(\d{1,3}\.){2}\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(:\d+)?$/],maxInstances:2,timeoutSeconds:30,memory:'256MiB'};
exports.economyV2=onRequest(options,createEconomyHandler({...shared,requireAppCheck:false,testFaults:true}));
exports.economyV2AppCheckProbe=onRequest(options,createEconomyHandler({...shared,requireAppCheck:true}));
