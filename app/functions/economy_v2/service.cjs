'use strict';
// Economic V2 service. No legacy imports; casino is separately gated to demo.
const {canonical,digest,EconomicError}=require('./common.cjs');
const {createCasinoService}=require('./casino/service.cjs');
const reject = (code,status) => {throw new EconomicError(code,status);};
const idPattern=/^[a-f0-9]{32}$/;
const sources=Object.freeze({
  'sandbox.match.v1':Object.freeze({kind:'income',amount:40}),
  'sandbox.card.v1':Object.freeze({kind:'asset',sku:'sandbox-card',assetType:'test-card'}),
});
const products=Object.freeze({'sandbox-shirt':Object.freeze({cost:10,assetType:'test-clothing'})});
const keysByAction={
  getWallet:[],initialize:['operationId'],claimIncome:['operationId','ticketId'],
  purchase:['operationId','sku'],issueTestAsset:['operationId','ticketId'],
  getOperation:['operationId','includePresentation'],history:['limit','cursor','includePresentation'],
  ackPresentation:['operationId','status'],getAsset:['instanceId'],
  requestSpin:['operationId','sequence','configId'],consumeFreeSpin:['operationId','sequence'],getCasinoState:[],
};
const mutating=new Set(['initialize','claimIncome','purchase','issueTestAsset','requestSpin','consumeFreeSpin']);
function validate(input,uid) {
  if (!input || Array.isArray(input) || typeof input!=='object') reject('invalid-request');
  if (typeof input.action!=='string' || !Object.hasOwn(keysByAction,input.action)) reject('unsupported-action');
  const allowed=['action','expectedOwnerUid',...keysByAction[input.action]];
  if (Object.keys(input).some(k=>!allowed.includes(k))) reject('unknown-fields');
  if (input.expectedOwnerUid!==uid) reject('account-changed',403);
  if (keysByAction[input.action].includes('operationId') && (typeof input.operationId!=='string'||!idPattern.test(input.operationId))) reject('invalid-operation-id');
  if (['claimIncome','issueTestAsset'].includes(input.action) && (typeof input.ticketId!=='string'||!/^[a-zA-Z0-9_-]{1,100}$/.test(input.ticketId))) reject('invalid-ticket-id');
  if (input.action==='purchase' && (typeof input.sku!=='string' || input.sku.length>100)) reject('invalid-sku');
  if (input.action==='getAsset' && (typeof input.instanceId!=='string'||!/^[a-f0-9]{64}$/.test(input.instanceId))) reject('invalid-instance-id');
  if (input.action==='ackPresentation' && !['seen','skipped'].includes(input.status)) reject('invalid-presentation');
  if (['requestSpin','consumeFreeSpin'].includes(input.action)&&(!Number.isSafeInteger(input.sequence)||input.sequence<0)) reject('invalid-sequence');
  if (input.action==='requestSpin'&&(typeof input.configId!=='string'||!/^[a-zA-Z0-9_-]{1,64}$/.test(input.configId))) reject('invalid-config-id');
  if(input.includePresentation!==undefined&&typeof input.includePresentation!=='boolean')reject('invalid-presentation-option');
  if (input.action==='history' && (input.limit!==undefined && (!Number.isInteger(input.limit)||input.limit<1||input.limit>50)
    || input.cursor!==undefined && (typeof input.cursor!=='string'||!idPattern.test(input.cursor)))) reject('invalid-pagination');
  return input;
}
function createEconomyService({db,syntheticEnabled=false,now=()=>Date.now(),casinoOptions=null}) {
  const casino=createCasinoService({db,now,...(casinoOptions||{})});
  const ref=(uid,collection,id)=>db.doc(`economies_v2/${uid}/${collection}/${id}`);
  const readReceipt=async(uid,id)=>{
    const snap=await ref(uid,'receipts',id).get();
    if (!snap.exists) reject('operation-not-found',404);
    return snap.data();
  };
  async function run(uid,claims,input,hooks={}) {
    validate(input,uid);
    const action=input.action;
    if (action==='getWallet') {
      const snap=await ref(uid,'wallet','main').get();
      return {wallet:snap.exists?snap.data():null,casinoEnabled:syntheticEnabled&&!!casinoOptions};
    }
    if (action==='getOperation') return {receipt:await readReceipt(uid,input.operationId),...(input.includePresentation?{
      presentation:(await ref(uid,'presentation',input.operationId).get()).data()?.status||'pending'}:{})};
    if (action==='getCasinoState') return casino.getState(uid);
    if (action==='history') {
      let query=db.collection(`economies_v2/${uid}/receipts`).orderBy('createdAt','desc').limit(input.limit||20);
      if (input.cursor) {
        const cursor=await ref(uid,'receipts',input.cursor).get();
        if (!cursor.exists) reject('invalid-cursor');
        query=query.startAfter(cursor);
      }
      const page=await query.get();
      const presentations={};
      if(input.includePresentation&&page.docs.length){
        const rows=await db.getAll(...page.docs.map(d=>ref(uid,'presentation',d.id)));
        rows.forEach((r,i)=>{presentations[page.docs[i].id]=r.data()?.status||'pending';});
      }
      return {receipts:page.docs.map(d=>d.data()),nextCursor:page.empty?null:page.docs.at(-1).id,
        ...(input.includePresentation?{presentations}:{})};
    }
    if (action==='ackPresentation') {
      await db.runTransaction(async tx=>{
        const receipt=await tx.get(ref(uid,'receipts',input.operationId));
        if (!receipt.exists) reject('operation-not-found',404);
        const presentation=ref(uid,'presentation',input.operationId),old=await tx.get(presentation);
        if (!old.exists || old.data().status==='pending') tx.set(presentation,{status:input.status,updatedAt:new Date(now()).toISOString()});
      });
      return {acknowledged:true};
    }
    if (action==='getAsset') {
      return db.runTransaction(async tx=>{
        const asset=await tx.get(ref(uid,'inventory',input.instanceId));
        if (!asset.exists) reject('unverified-asset',409);
        const data=asset.data();
        if (!idPattern.test(data.originId||'')) reject('unverified-asset',409);
        const [origin,receipt]=await tx.getAll(ref(uid,'origins',data.originId),ref(uid,'receipts',data.originId));
        if (!origin.exists||!receipt.exists) reject('unverified-asset',409);
        const o=origin.data(),r=receipt.data(),{receiptHash,...financial}=r;
        if (data.instanceId!==input.instanceId||data.ownerUid!==uid||data.state!=='available'||o.ownerUid!==uid||o.instanceId!==data.instanceId
          ||o.operationId!==data.originId||r.operationId!==data.originId
          ||r.status!=='committed'||r.ownerUid!==uid||r.result?.instanceId!==data.instanceId||r.result?.sku!==data.sku
          ||o.assetHash!==digest(data)||receiptHash!==digest(financial)||o.receiptHash!==receiptHash) reject('unverified-asset',409);
        return {asset:data,origin:o};
      });
    }
    // All financial writers in this stage require a demo environment and a server-set
    // participant claim. Neither a request parameter nor legacy progress enables them.
    if (!syntheticEnabled || claims.economySandbox!==true) reject('synthetic-policy-disabled',403);
    if (['requestSpin','consumeFreeSpin'].includes(action)) {
      if(!casinoOptions) reject('casino-disabled',403);
      return casino.run(uid,input,hooks);
    }
    const operationId=input.operationId,requestHash=digest({apiVersion:2,ownerUid:uid,...input});
    const createdAt=new Date(now()).toISOString();
    const receiptRef=ref(uid,'receipts',operationId),walletRef=ref(uid,'wallet','main');
    const result=await db.runTransaction(async tx=>{
      const old=await tx.get(receiptRef);
      if (old.exists) {
        if(old.data().requestHash!==requestHash) reject('id-collision',409);
        return old.data();
      }
      const walletSnap=await tx.get(walletRef),wallet=walletSnap.data();
      let cost=0,gross=0,code=null,ticketRef,assetSpec;
      if (action==='initialize') {
        if(walletSnap.exists) code='already-initialized';
        else gross=100; // sandbox.bootstrap.v1, never real player funds
      } else if (!walletSnap.exists) code='wallet-not-initialized';
      else if (wallet.status!=='sandbox-active' || !Number.isSafeInteger(wallet.balance) || wallet.balance<0
        || !Number.isSafeInteger(wallet.revision) || wallet.revision<1) reject('invalid-server-state',500);
      if (!code && action==='purchase') {
        const product=Object.hasOwn(products,input.sku)?products[input.sku]:null;
        if (!product) code='unknown-product';
        else {cost=product.cost;assetSpec={sku:input.sku,assetType:product.assetType};}
      }
      if (!code && ['claimIncome','issueTestAsset'].includes(action)) {
        ticketRef=ref(uid,'incomeTickets',input.ticketId);
        const snap=await tx.get(ticketRef),t=snap.data(),policy=t&&Object.hasOwn(sources,t.source)?sources[t.source]:null;
        if(!snap.exists||t.ownerUid!==uid||t.issuer!=='sandbox-fixture.v1'||!policy
          ||!Number.isSafeInteger(t.expiresAt)||t.expiresAt<=now()||t.consumedBy) code='invalid-source';
        else if(action==='claimIncome'&&policy.kind==='income') gross=policy.amount;
        else if(action==='issueTestAsset'&&policy.kind==='asset') assetSpec={sku:policy.sku,assetType:policy.assetType};
        else code='source-kind-mismatch';
      }
      if(!code && walletSnap.exists && wallet.balance<cost) code='insufficient-funds';
      const before=walletSnap.exists?wallet.balance:0,revision=walletSnap.exists?wallet.revision:0;
      if(!Number.isSafeInteger(before)||!Number.isSafeInteger(revision)) reject('invalid-server-state',500);
      const delta=code?0:gross-cost,after=before+delta;
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(revision+1)) reject('balance-overflow',409);
      const instanceId=!code&&assetSpec?digest({uid,operationId,sku:assetSpec.sku}):null;
      const financial={schemaVersion:2,operationId,ownerUid:uid,requestHash,action,
        policyVersion:'sandbox.economy.v1',createdAt,status:code?'declined':'committed',code,
        chargedCost:code?0:cost,grossPrize:code?0:gross,netDelta:delta,
        balanceBefore:before,balanceAfter:after,revisionBefore:revision,revisionAfter:code?revision:revision+1,
        previousMovementHash:wallet?.headHash||null,
        sourceId:input.ticketId||null,result:instanceId?{instanceId,originId:operationId,...assetSpec}:{}};
      const receipt={...financial,receiptHash:digest(financial)};
      await hooks.beforeCommit?.();
      tx.create(receiptRef,receipt);
      tx.create(ref(uid,'presentation',operationId),{status:'pending',updatedAt:createdAt});
      if(!code) {
        tx.set(walletRef,{schemaVersion:2,ownerUid:uid,currency:'sandboxVerifiedCoins',status:'sandbox-active',
          balance:after,revision:revision+1,headHash:receipt.receiptHash,updatedAt:createdAt});
        tx.create(ref(uid,'movements',operationId),{ownerUid:uid,operationId,delta,balanceBefore:before,balanceAfter:after,
          revisionBefore:revision,revisionAfter:revision+1,previousHash:financial.previousMovementHash,receiptHash:receipt.receiptHash});
        if(action==='initialize') tx.create(ref(uid,'compatibility','current'),{
          schemaVersion:2,status:'sandbox-only',legacyPromoted:false,policyVersion:'sandbox.bootstrap.v1'});
        if(ticketRef) tx.update(ticketRef,{consumedBy:operationId,consumedAt:createdAt});
        if(instanceId) {
          const asset={schemaVersion:2,instanceId,originId:operationId,ownerUid:uid,state:'available',...assetSpec};
          tx.create(ref(uid,'inventory',instanceId),asset);
          tx.create(ref(uid,'origins',operationId),{schemaVersion:2,ownerUid:uid,instanceId,operationId,
            source:'sandbox-only',assetHash:digest(asset),receiptHash:receipt.receiptHash});
        }
      }
      return receipt;
    });
    await hooks.afterCommit?.();
    return {receipt:result};
  }
  return {run,ref};
}
module.exports={createEconomyService,EconomicError,digest,canonical,validate,mutating};
