'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {canonical,digest,validate,createEconomyService}=require('../economy_v2/service.cjs');
const {isolatedDemo,privateDemoOrigin}=require('../economy_v2/http.cjs');
test('4C2 browser origin guard is limited to HTTP private demo origins',()=>{
  for(const origin of ['http://localhost:8091','http://127.0.0.1:8091','http://10.0.2.2:8091','http://192.168.1.20:8091'])assert.equal(privateDemoOrigin(origin),true);
  for(const origin of ['https://example.com','http://example.com','http://127.0.0.1.evil.com:8091','null','http://127.0.0.1:8091/path'])assert.equal(privateDemoOrigin(origin),false);
});
const op='a'.repeat(32),uid='alice';
test('V2 canonical request hashing ignores key insertion order, preserves meaning and owner',()=>{
  assert.equal(canonical({b:{d:2,a:1},a:0}),'\{"a":0,"b":{"a":1,"d":2}}');
  assert.equal(digest({a:1,b:2}),digest({b:2,a:1}));
  assert.notEqual(digest({owner:'alice',id:op}),digest({owner:'bob',id:op}));
});
test('V2 strict schema rejects coerced IDs, client economics and prototype lookup names',()=>{
  const input={action:'purchase',expectedOwnerUid:uid,operationId:op,sku:'sandbox-shirt'};
  assert.equal(validate(input,uid),input);
  for(const patch of [{operationId:[op]},{action:['purchase']},{amount:999},{sku:0},{expectedOwnerUid:'bob'}]) {
    assert.throws(()=>validate({...input,...patch},uid));
  }
  for(const action of ['constructor','toString','__proto__','requestSpin','consumeFreeSpin']) assert.throws(()=>validate({...input,action},uid));
});
test('V2 sandbox requires emulator, exact demo project and both loopback hosts',()=>{
  const env={FUNCTIONS_EMULATOR:'true',GCLOUD_PROJECT:'demo-lucky-readiness',FIRESTORE_EMULATOR_HOST:'127.0.0.1:18186',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:19099'};
  assert.equal(isolatedDemo(env),true);
  for(const patch of [{FUNCTIONS_EMULATOR:'false'},{GCLOUD_PROJECT:'real-project'},{FIRESTORE_EMULATOR_HOST:'firestore.googleapis.com:443'},{FIREBASE_AUTH_EMULATOR_HOST:undefined}]) assert.equal(isolatedDemo({...env,...patch}),false);
});
test('V2 financial service is disabled by default even with synthetic participant claim',async()=>{
  const service=createEconomyService({db:{}});
  await assert.rejects(service.run(uid,{economySandbox:true},{action:'initialize',expectedOwnerUid:uid,operationId:op}),/synthetic-policy-disabled/);
});
