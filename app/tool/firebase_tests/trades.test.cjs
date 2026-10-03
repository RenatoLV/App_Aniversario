// Integration test against local emulators only; never creates real users.
const assert = require('node:assert/strict');
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST)
  throw Error('Run through firebase emulators:exec.');
const requireFunctions = require('node:module').createRequire(require('node:path').resolve(__dirname,'../../functions/package.json'));
const {initializeApp} = requireFunctions('firebase-admin/app');
const {getFirestore} = requireFunctions('firebase-admin/firestore');
initializeApp({projectId:'demo-anivermaru'});
const db=getFirestore();
const endpoint='http://127.0.0.1:5001/demo-anivermaru/us-central1/cardTrades';
async function user() {
  const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});
  assert.equal(r.status,200); return r.json();
}
async function call(who,body,status=200) {
  const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',...(who?{Authorization:'Bearer '+who.idToken}:{})},body:JSON.stringify(body)});
  const data=await r.json(); assert.equal(r.status,status,JSON.stringify(data));return data;
}
async function seed(who,variants) {
  await db.doc(`players/${who.localId}`).set({nickname:'Test player'});
  await db.doc(`players/${who.localId}/progress/current`).set({revision:1,
    payload:JSON.stringify({'rincon.v1':JSON.stringify({coins:600,cardVariants:variants,cards:{},rarities:{}})})});
}
async function core(who) {
  return JSON.parse(JSON.parse((await db.doc(`players/${who.localId}/progress/current`).get()).data().payload)['rincon.v1']);
}
async function privateDoc(who,path,method='GET',status=200) {
  const r=await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/demo-anivermaru/databases/(default)/documents/${path}`,{
    method,headers:{Authorization:'Bearer '+who.idToken,'Content-Type':'application/json'},
    ...(method==='PATCH'?{body:JSON.stringify({fields:{status:{stringValue:'accepted'}}})}:{})});
  assert.equal(r.status,status,await r.text());
}
(async () => {
  const [a,b,c]=await Promise.all([user(),user(),user()]);
  await seed(a,{'1:rare:silver':2});await seed(b,{'2:epic:gold':1});await seed(c,{});
  await call(null,{action:'publish'},401);
  await call(b,{action:'publish'});
  const view=await call(a,{action:'view',target:b.localId});
  assert.deepEqual(Object.keys(view).sort(),['name','variants']);assert.equal(view.variants['2:epic:gold'],1);
  const id='a'.repeat(32);
  await call(a,{action:'propose',target:b.localId,give:'1:rare:silver',receive:'2:epic:gold',id});
  await privateDoc(a,`card_trades/${id}`);
  await privateDoc(b,`card_trades/${id}`);
  await privateDoc(c,`card_trades/${id}`,'GET',403);
  await privateDoc(a,`card_trades/${id}`,'PATCH',403);
  await privateDoc(a,`players/${b.localId}/progress/current`,'GET',403);
  await privateDoc(c,`card_collections/${b.localId}`);
  await privateDoc(b,`card_collections/${b.localId}`,'PATCH',403);
  await call(c,{action:'respond',id,choice:'accept'},400);
  await call(a,{action:'respond',id,choice:'accept'},400);
  await call(b,{action:'respond',id,choice:'accept'});
  const first=await core(a);const second=await core(b);
  assert.equal(first.cardVariants['1:rare:silver'],1);assert.equal(first.cardVariants['2:epic:gold'],1);
  assert.deepEqual(second.cardVariants,{'1:rare:silver':1});
  assert.equal(first.coins,600);assert.equal(second.coins,600);
  await call(b,{action:'respond',id,choice:'accept'});assert.deepEqual(await core(a),first);
  const id2='b'.repeat(32);
  await call(a,{action:'propose',target:b.localId,give:'2:epic:gold',receive:'1:rare:silver',id:id2});
  await seed(b,{});
  await call(b,{action:'respond',id:id2,choice:'accept'},400);
  assert.equal((await db.doc(`card_trades/${id2}`).get()).data().status,'pending');
  assert.deepEqual(await core(a),first);
  await call(a,{action:'respond',id:id2,choice:'cancel'});
  await call(b,{action:'respond',id:id2,choice:'accept'},400);
  console.log('Trade integration passed: authenticated users, exact variants, atomic ownership, repeat acceptance, missing copy rollback and cancellation.');
})().catch(e=>{console.error(e);process.exitCode=1;});
