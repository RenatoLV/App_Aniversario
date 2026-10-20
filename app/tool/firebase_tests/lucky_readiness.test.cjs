'use strict';
// Local emulator characterization only. Never targets real users or production.
const assert=require('node:assert/strict');
const project='demo-lucky-readiness',host=process.env.FIRESTORE_EMULATOR_HOST,
  auth=process.env.FIREBASE_AUTH_EMULATOR_HOST;
if(!/^127\.0\.0\.1:\d+$/.test(host||'')||!/^127\.0\.0\.1:\d+$/.test(auth||''))
  throw Error('Only localhost Firestore/Auth emulators are allowed');
async function user() {
  const r=await fetch(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});
  assert.equal(r.status,200);return r.json();
}
async function write(actor,path,revision,payload,expected) {
  const r=await fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents/${path}`,{
    method:'PATCH',headers:{Authorization:`Bearer ${actor.idToken}`,'Content-Type':'application/json'},
    body:JSON.stringify({fields:{revision:{integerValue:String(revision)},payload:{stringValue:payload}}})});
  assert.equal(r.status,expected,await r.text());
}
(async()=>{
  const a=await user(),b=await user(),p=`players/${a.localId}/progress/current`;
  const payload=coins=>JSON.stringify({'rincon.v1':JSON.stringify({coins,cardVariants:{'10000:celestial:gold':1}})});
  await write(a,p,1,payload(30),200);
  // This is a documented gap: the current rule checks ownership/revision/size,
  // not the source of coins or variants inside the opaque payload.
  await write(a,p,2,payload(1000000),200);
  await write(b,p,3,payload(1000000),403);
  await write(a,`card_collections/${a.localId}`,1,'{}',403);
  console.log('Readiness characterization: owner payload edits allowed; other owners and public inventory writes denied. Legacy payload is not an economic authority.');
})().catch(e=>{console.error(e);process.exitCode=1;});
