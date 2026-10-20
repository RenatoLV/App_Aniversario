'use strict';
// EMULATOR TEST ADAPTER ONLY. No HTTP export, production import, or casino RNG.
// Fixed outcomes test database atomicity, NOT the future server slot evaluator.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const path = require('node:path');
const functionsRequire = createRequire(path.join(__dirname,'../../functions/package.json'));
const {initializeApp,cert} = functionsRequire('firebase-admin/app');
const {getFirestore} = functionsRequire('firebase-admin/firestore');
const project = 'demo-lucky-readiness';
for (const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST']) {
  assert.match(process.env[name] || '', /^127\.0\.0\.1:\d+$/);
}
assert.equal(process.env.GCLOUD_PROJECT, project);
assert.equal(process.versions.node.split('.')[0], '22');
// Ephemeral fake certificate avoids ADC/metadata discovery and cannot authenticate
// to a real project. Firestore emulator uses its local admin transport instead.
const fakeKey = crypto.generateKeyPairSync('rsa',{modulusLength:2048}).privateKey
  .export({type:'pkcs8',format:'pem'});
const db = getFirestore(initializeApp({projectId: project,credential:cert({
  projectId:project,clientEmail:`emulator@${project}.iam.gserviceaccount.com`,privateKey:fakeKey,
})}));
const base = uid => `economies_v2/${uid}`;
const ref = (uid, group, id) => db.doc(`${base(uid)}/${group}/${id}`);
const fail = code => { throw Error(code); };
async function seed(uid) {
  const batch = db.batch();
  batch.set(ref(uid,'wallet','main'), {balance:100,revision:0,currency:'verifiedCoins'});
  batch.set(ref(uid,'casinoState','lucky777'), {sequence:0,remaining:0,awarded:0,stake:25,rules:'fixture-v1'});
  batch.set(ref(uid,'compatibility','current'), {status:'sandbox',legacyPromoted:false});
  await batch.commit();
}
async function operate(authUid, input, fault) {
  if (!authUid) fail('unauthenticated');
  if (input.expectedOwnerUid !== authUid) fail('account-changed');
  if (!/^[a-f0-9]{32}$/.test(input.id)) fail('invalid-id');
  const allowed = ['id','expectedOwnerUid','kind','sequence','ticketId','sku'];
  if (Object.keys(input).some(k=>!allowed.includes(k))) fail('client-economic-input');
  if (!['paid','free','purchase','income'].includes(input.kind)) fail('invalid-kind');
  const hash = crypto.createHash('sha256').update(JSON.stringify(
    allowed.map(k=>[k,input[k] ?? null]))).digest('hex');
  const receiptRef = ref(authUid,'receipts',input.id);
  const receipt = await db.runTransaction(async tx => {
    const old = await tx.get(receiptRef);
    if (old.exists) {
      if (old.data().requestHash !== hash) fail('id-collision');
      return old.data();
    }
    const walletRef=ref(authUid,'wallet','main'), stateRef=ref(authUid,'casinoState','lucky777');
    const [wallet, state] = await tx.getAll(walletRef,stateRef);
    if (!wallet.exists || !state.exists) fail('not-enrolled');
    const w=wallet.data(), s=state.data();
    let cost=0, gross=0, ticketRef, inventoryRef;
    if (input.kind==='paid' || input.kind==='free') {
      if (input.sequence!==s.sequence) fail('stale-sequence');
      if ((input.kind==='free') !== (s.remaining>0)) fail('bonus-mismatch');
      // Deliberately fixed TEST fixtures, no caller-selected prize or production rules.
      cost=input.kind==='paid'?25:0; gross=input.kind==='paid'?20:0;
      if (input.kind==='paid') {s.remaining=12;s.awarded=12;}
      else {s.remaining--;}
      s.sequence++;
    } else if (input.kind==='purchase') {
      if (input.sku!=='test-shirt') fail('unknown-sku');
      cost=10; inventoryRef=ref(authUid,'inventory','test-shirt');
      if ((await tx.get(inventoryRef)).exists) fail('already-owned');
    } else {
      if (!/^[a-z0-9-]{1,64}$/.test(input.ticketId||'')) fail('invalid-ticket');
      ticketRef=ref(authUid,'incomeTickets',input.ticketId);
      const ticket=await tx.get(ticketRef);
      if (!ticket.exists || ticket.data().used || ticket.data().ownerUid!==authUid) fail('invalid-ticket');
      gross=ticket.data().amount; // Seeded by the TEST server, never by this client.
    }
    if (![w.balance,w.revision,cost,gross].every(Number.isSafeInteger) || cost<0 || gross<0) fail('invalid-server-state');
    if (w.balance<cost) fail('insufficient');
    if (!Number.isSafeInteger(w.balance-cost+gross)) fail('overflow');
    const next={...w,balance:w.balance-cost+gross,revision:w.revision+1};
    const result={id:input.id,ownerUid:authUid,requestHash:hash,kind:input.kind,cost,gross,
      net:gross-cost,balance:next.balance,revision:next.revision,presentation:'pending',
      rulesVersion:'fixture-v1',bonusAfter:s};
    if (fault==='beforeCommit') fail('injected-before-commit');
    tx.set(walletRef,next);
    tx.create(receiptRef,result);
    tx.create(ref(authUid,'movements',input.id),{operationId:input.id,delta:result.net,revision:next.revision});
    tx.create(ref(authUid,'presentation',input.id),{status:'pending'});
    if (input.kind==='paid' || input.kind==='free') {
      tx.set(stateRef,s);tx.create(ref(authUid,'casinoRounds',input.id),result);
    }
    if (ticketRef) tx.update(ticketRef,{used:true,operationId:input.id});
    if (inventoryRef) {
      tx.create(inventoryRef,{ownerUid:authUid,originId:input.id,verified:true,sku:input.sku});
      tx.create(ref(authUid,'origins',input.id),{ownerUid:authUid,operationId:input.id,sku:input.sku,source:'test-purchase'});
    }
    return result;
  });
  if (fault==='afterCommit') fail('injected-lost-response');
  return receipt;
}
async function transferVerified(from,to,item,id) {
  // Only a provenance-boundary example. Not the production two-party trade protocol.
  await db.runTransaction(async tx=>{
    const itemRef=ref(from,'inventory',item), destination=ref(to,'inventory',item);
    const snapshot=await tx.get(itemRef);
    if (!snapshot.exists) fail('unverified-origin');
    const data=snapshot.data();
    if (!data.verified || data.ownerUid!==from || !/^[a-f0-9]{32}$/.test(data.originId||'')) fail('unverified-origin');
    const origin=await tx.get(ref(from,'origins',data.originId));
    if (!origin.exists || origin.data().sku!==item || origin.data().ownerUid!==from) fail('unverified-origin');
    if ((await tx.get(destination)).exists) fail('already-owned');
    tx.delete(itemRef); tx.create(destination,{...data,ownerUid:to,originId:id});
    tx.create(ref(to,'origins',id),{ownerUid:to,sku:item,source:'test-transfer',previousOwner:from,previousOrigin:data.originId});
  });
}
module.exports={db,project,ref,seed,operate,transferVerified};
