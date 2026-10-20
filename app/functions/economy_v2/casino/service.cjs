'use strict';
const {digest,EconomicError}=require('../common.cjs');
const {getConfig,configs,rulesHash,evaluateStops}=require('./engine.cjs');
const {createRandom}=require('./rng.cjs');
const ref=(db,uid,group,id)=>db.doc(`economies_v2/${uid}/${group}/${id}`);
const emptyState=()=>({schemaVersion:2,sequence:0,bonus:null});
function rngContext(uid,input,intent) {
  return {ownerUid:uid,operationId:input.operationId,sequence:input.sequence,machineId:'lucky777',
    rulesVersion:intent.rulesVersion,rulesHash:intent.rulesHash,referenceStake:intent.referenceStake,
    bonusId:intent.bonusId,keyEpoch:intent.keyEpoch,action:input.action};
}
function createCasinoService({db,now=()=>Date.now(),keyring=null,currentEpoch=null}) {
  async function policy(tx) {
    const snap=await tx.get(db.doc('economy_v2_server/casino'));
    return snap.exists?snap.data():{enabledConfigs:['reference25','scaled10'],currentEpoch};
  }
  async function getState(uid) {
    return db.runTransaction(async tx=>{
      const [snap,p]=await Promise.all([tx.get(ref(db,uid,'casinoState','lucky777')),policy(tx)]);
      return {state:snap.exists?snap.data():emptyState(),configs:Object.entries(configs)
        .filter(([id])=>p.enabledConfigs?.includes(id)).map(([configId,r])=>({configId,rulesVersion:r.rulesVersion,
          rulesHash:rulesHash(r),catalogVersion:r.catalogVersion,wager:r.lineStake*5}))};
    });
  }
  async function run(uid,input,hooks={}) {
    if(!keyring||!currentEpoch)throw new EconomicError('casino-disabled',403);
    const requestHash=digest({apiVersion:2,ownerUid:uid,...input});
    const receiptRef=ref(db,uid,'receipts',input.operationId),intentRef=ref(db,uid,'casinoIntents',input.operationId);
    // Durable admission pins epoch/config/context across failed commits, process
    // restarts and policy rotation. No money moves in this preparatory transaction.
    const admission=await db.runTransaction(async tx=>{
      const [receipt,old]=await tx.getAll(receiptRef,intentRef);
      if(receipt.exists){if(receipt.data().requestHash!==requestHash)throw new EconomicError('id-collision',409);return {receipt:receipt.data()};}
      if(old.exists){if(old.data().requestHash!==requestHash)throw new EconomicError('id-collision',409);return {intent:old.data()};}
      const [stateSnap,p]=await Promise.all([tx.get(ref(db,uid,'casinoState','lucky777')),policy(tx)]);
      const state=stateSnap.exists?stateSnap.data():emptyState();
      const free=input.action==='consumeFreeSpin';
      const configId=free?state.bonus?.configId:input.configId,rules=getConfig(configId);
      let declineCode=null;
      if(!Number.isSafeInteger(state.sequence)||state.sequence<0)throw new EconomicError('invalid-casino-state',500);
      if(input.sequence!==state.sequence)declineCode='stale-sequence';
      else if(free&&!state.bonus?.remaining)declineCode='bonus-not-active';
      else if(!free&&state.bonus?.remaining)declineCode='bonus-active';
      else if(!rules||!free&&!p.enabledConfigs?.includes(configId))declineCode='config-not-authorized';
      const intent={schemaVersion:2,ownerUid:uid,operationId:input.operationId,requestHash,
        configId:configId||null,rulesVersion:free?state.bonus?.rulesVersion||null:rules?.rulesVersion||null,
        rulesHash:free?state.bonus?.rulesHash||null:rules?rulesHash(rules):null,
        referenceStake:free?state.bonus?.referenceStake||0:rules?rules.lineStake*5:0,
        keyEpoch:free?state.bonus?.keyEpoch||p.currentEpoch:p.currentEpoch,
        bonusId:free?state.bonus?.bonusId||null:input.operationId,
        stateHash:digest(state),declineCode,admittedAt:new Date(now()).toISOString()};
      tx.create(intentRef,intent);return {intent};
    });
    if(admission.receipt)return {receipt:admission.receipt};
    const intent=admission.intent;
    const createdAt=intent.admittedAt;
    const receipt=await db.runTransaction(async tx=>{
      const old=await tx.get(receiptRef);
      if(old.exists){if(old.data().requestHash!==requestHash)throw new EconomicError('id-collision',409);return old.data();}
      const walletRef=ref(db,uid,'wallet','main'),stateRef=ref(db,uid,'casinoState','lucky777');
      const [walletSnap,stateSnap]=await tx.getAll(walletRef,stateRef);
      const wallet=walletSnap.data(),state=stateSnap.exists?stateSnap.data():emptyState();
      let code=intent.declineCode;
      if(!code&&input.sequence!==state.sequence)code='stale-sequence';
      if(!code&&intent.stateHash!==digest(state))code='casino-state-changed';
      if(!code&&!walletSnap.exists)code='wallet-not-initialized';
      if(walletSnap.exists&&(wallet.status!=='sandbox-active'||wallet.currency!=='sandboxVerifiedCoins'
        ||!Number.isSafeInteger(wallet.balance)||wallet.balance<0||!Number.isSafeInteger(wallet.revision)||wallet.revision<1))throw new EconomicError('invalid-server-state',500);
      const free=input.action==='consumeFreeSpin',cost=free?0:intent.referenceStake;
      if(!code&&wallet.balance<cost)code='insufficient-funds';
      let round=null,next=state;
      if(!code){
        const rules=getConfig(intent.configId),key=keyring[intent.keyEpoch];
        if(!rules||rulesHash(rules)!==intent.rulesHash||rules.rulesVersion!==intent.rulesVersion
          ||rules.lineStake*5!==intent.referenceStake||!key)throw new EconomicError('archived-config-unavailable',503);
        const before=free?state.bonus:{remaining:0,awarded:0};
        const random=createRandom(key,rngContext(uid,input,intent));
        round=evaluateStops(rules.reels.map(reel=>random.nextInt(reel.length)),rules,before);
        if(round.freeSpin!==free)throw new EconomicError('invalid-bonus-state',500);
        next={schemaVersion:2,sequence:state.sequence+1,bonus:round.remaining>0?{
          bonusId:intent.bonusId,configId:intent.configId,rulesVersion:intent.rulesVersion,rulesHash:intent.rulesHash,
          referenceStake:intent.referenceStake,keyEpoch:intent.keyEpoch,remaining:round.remaining,awarded:round.awarded,
          cycleGross:(free?state.bonus.cycleGross:0)+round.amount,
        }:null};
      }
      const before=wallet?.balance||0,revision=wallet?.revision||0,gross=code?0:round.amount,chargedCost=code?0:cost;
      const after=before-chargedCost+gross;
      if(!Number.isSafeInteger(after)||after<0||!Number.isSafeInteger(revision+1)||!Number.isSafeInteger(next.sequence))throw new EconomicError('balance-overflow',409);
      const financial={schemaVersion:2,operationId:input.operationId,ownerUid:uid,requestHash,action:input.action,
        policyVersion:'sandbox.casino.v1',createdAt,status:code?'declined':'committed',code,
        chargedCost,grossPrize:gross,netDelta:gross-chargedCost,balanceBefore:before,balanceAfter:after,
        revisionBefore:revision,revisionAfter:code?revision:revision+1,previousMovementHash:wallet?.headHash||null,
        sourceId:null,result:round?{configId:intent.configId,rulesHash:intent.rulesHash,keyEpoch:intent.keyEpoch,
          bonusId:intent.bonusId,sequenceBefore:state.sequence,sequenceAfter:next.sequence,
          bonusBefore:state.bonus,bonusAfter:next.bonus,
          cycleGross:(free?state.bonus.cycleGross:0)+round.amount,
          cycleNet:(free?state.bonus.cycleGross:0)+round.amount-intent.referenceStake,round}:{} };
      const record={...financial,receiptHash:digest(financial)};
      await hooks.beforeCommit?.({round,receipt:record});
      tx.create(receiptRef,record);tx.create(ref(db,uid,'presentation',input.operationId),{status:'pending',updatedAt:createdAt});
      if(!code){
        tx.set(walletRef,{...wallet,balance:after,revision:revision+1,headHash:record.receiptHash,updatedAt:createdAt});
        tx.create(ref(db,uid,'movements',input.operationId),{ownerUid:uid,operationId:input.operationId,
          delta:record.netDelta,balanceBefore:before,balanceAfter:after,revisionBefore:revision,
          revisionAfter:revision+1,previousHash:record.previousMovementHash,receiptHash:record.receiptHash});
        tx.create(ref(db,uid,'casinoRounds',input.operationId),record.result);
        tx.set(stateRef,next);
      }
      return record;
    });
    await hooks.afterCommit?.();
    return {receipt};
  }
  return {run,getState};
}
module.exports={createCasinoService,rngContext,emptyState};
