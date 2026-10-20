'use strict';
// AUDIT CONTRACT MODEL ONLY. No Firebase adapter, exported Function, wallet or deployment.
// Validates proposed invariants against memory faults, not a stage-4 implementation.
const {test}=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const fixtures=JSON.parse(fs.readFileSync(path.join(__dirname,'../../tool/lucky_stage35_economy.json'),'utf8')).referenceFixtures;
const clone=v=>structuredClone(v);
class ContractModel {
  constructor(saved) {
    this.state=clone(saved||{accounts:{alice:{coins:100,sequence:0,bonus:{remaining:0,awarded:0}},bob:{coins:100,sequence:0,bonus:{remaining:0,awarded:0}}},receipts:{}});
    this.tail=Promise.resolve(); this.entropyTrace=[];
  }
  request(input, fault) {
    const run=this.tail.then(()=>this.apply(input,fault));
    this.tail=run.catch(()=>{}); return run;
  }
  apply(input,fault) {
    const {authUid,id,sequence,fixture='scatter',kind='paid',stake=25,version='lucky777.rules.candidate.v1'}=input;
    if(!this.state.accounts[authUid]) throw Error('unauthenticated');
    if(input.expectedOwnerUid && input.expectedOwnerUid!==authUid) throw Error('account changed');
    if(!/^[a-f0-9]{32}$/.test(id)) throw Error('invalid id');
    // Production must use authenticated UID, fixed allowlists and a secret epoch.
    const spec={owner:authUid,id,sequence,kind,stake,version,fixture};
    const digest=crypto.createHash('sha256').update(JSON.stringify(spec)).digest('hex'),key=`${authUid}:${id}`;
    const old=this.state.receipts[key];
    if(old) { if(old.paramsHash!==digest) throw Error('id collision'); return clone(old); }
    const account=this.state.accounts[authUid];
    if(account.sequence!==sequence) throw Error('stale sequence');
    if(stake!==25 || version!=='lucky777.rules.candidate.v1') throw Error('unsupported rules');
    if(kind==='free' && !account.bonus.remaining || kind==='paid' && account.bonus.remaining) throw Error('bonus mismatch');
    const cost=kind==='free'?0:stake;
    if(account.coins<cost) throw Error('insufficient');
    // Fixture is injected by tests. This is NOT a Node port of the slot evaluator.
    // The stable entropy contract avoids changing entropy on a transaction retry.
    const entropy=crypto.createHmac('sha256','FAKE-AUDIT-KEY-NOT-A-DEPLOYMENT-SECRET').update(digest).digest('hex');
    this.entropyTrace.push(entropy);
    const result=clone(fixtures[fixture]);
    const before=clone(account),awarded=kind==='free'?before.bonus.awarded:0,
      grant=Math.min(result.grantedSpins,50-awarded),after=clone(before);
    after.coins+=result.amount-cost;after.sequence++;
    after.bonus={remaining:(kind==='free'?before.bonus.remaining-1:0)+grant,awarded:awarded+grant};
    const receipt={owner:authUid,id,paramsHash:digest,rulesVersion:version,cost,
      gross:result.amount,net:result.amount-cost,result,
      before,after,presentation:'pending'};
    if(fault==='beforeCommit') throw Error('storage failure');
    // One in-memory swap stands for a future multi-document Firestore transaction.
    const next=clone(this.state);next.accounts[authUid]=after;next.receipts[key]=receipt;this.state=next;
    if(fault==='afterCommit') throw Error('acknowledgement lost');
    return clone(receipt);
  }
  seen(uid,id) {
    const receipt=this.state.receipts[`${uid}:${id}`]; if(!receipt) throw Error('not owned');
    receipt.presentation='seen';
  }
}
const request={authUid:'alice',expectedOwnerUid:'alice',id:'a'.repeat(32),sequence:0};
test('contract: duplicate request commits one debit, one prize and one bonus grant',async()=>{
  const a=new ContractModel();const [first,second]=await Promise.all([a.request(request),a.request(request)]);
  assert.deepEqual(first,second);assert.equal(a.state.accounts.alice.coins,95);
  assert.equal(first.gross,20);assert.equal(first.net,-5);assert.equal(first.after.bonus.remaining,12);
  assert.equal(a.entropyTrace.length,1);
});
test('contract: failure before commit preserves account and entropy across retry',async()=>{
  const a=new ContractModel(),before=clone(a.state);
  await assert.rejects(a.request(request,'beforeCommit'),/storage/);assert.deepEqual(a.state,before);
  await a.request(request);assert.equal(a.entropyTrace.length,2);assert.equal(a.entropyTrace[0],a.entropyTrace[1]);
});
test('contract: lost response and restored client recover same receipt without another debit',async()=>{
  const a=new ContractModel();await assert.rejects(a.request(request,'afterCommit'),/lost/);
  const b=new ContractModel(JSON.parse(JSON.stringify(a.state))),receipt=await b.request(request);
  assert.equal(b.state.accounts.alice.coins,95);assert.equal(receipt.after.bonus.remaining,12);
  assert.equal(b.entropyTrace.length,0);
});
test('contract: two devices on one sequence cannot both spend',async()=>{
  const a=new ContractModel();const result=await Promise.allSettled([a.request(request),a.request({...request,id:'b'.repeat(32)})]);
  assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(Object.keys(a.state.receipts).length,1);
});
test('contract: reused id with changed parameters is rejected',async()=>{
  const a=new ContractModel();await a.request(request);
  await assert.rejects(a.request({...request,stake:10}),/collision/);assert.equal(a.state.accounts.alice.coins,95);
});
test('contract: late retry after account switch cannot charge the new owner',async()=>{
  const a=new ContractModel();await assert.rejects(a.request(request,'afterCommit'),/lost/);
  await assert.rejects(a.request({...request,authUid:'bob'}),/account changed/);
  assert.equal(a.state.accounts.alice.coins,95);assert.equal(a.state.accounts.bob.coins,100);
  assert.equal((await a.request(request)).owner,'alice');
});
test('contract: free spin consumes bonus, no debit; presentation cannot regrant',async()=>{
  const a=new ContractModel();await a.request(request);
  const free=await a.request({...request,id:'b'.repeat(32),sequence:1,kind:'free',fixture:'quiet'});
  assert.equal(free.cost,0);assert.equal(free.after.coins,95);assert.equal(free.after.bonus.remaining,11);
  for(let i=0;i<5;i++)a.seen('alice',request.id);
  assert.equal(a.state.accounts.alice.coins,95);assert.equal(a.state.accounts.alice.bonus.remaining,11);
});
test('contract: ownership and insufficient funds leave state intact',async()=>{
  const a=new ContractModel();assert.throws(()=>a.seen('bob',request.id),/owned/);
  await assert.rejects(a.request({...request,authUid:'unknown'}),/unauthenticated/);
  a.state.accounts.alice.coins=24;const before=clone(a.state);
  await assert.rejects(a.request(request),/insufficient/);assert.deepEqual(a.state,before);
});
test('characterization: trade transfer trusts declared legacy inventory, not acquisition proof',()=>{
  const {transfer,unpack}=require('../inventory.cjs');
  const doc=variants=>({revision:1,payload:JSON.stringify({'rincon.v1':JSON.stringify({coins:30,cardVariants:variants})})});
  // No acquisition receipt or signed origin exists in either synthetic snapshot.
  const [a,b]=transfer(doc({'10000:celestial:gold':1}),doc({'1:rare:normal':1}),
    '10000:celestial:gold','1:rare:normal','audit-only');
  assert.equal(unpack({payload:b}).core.cardVariants['10000:celestial:gold'],1);
  assert.equal(unpack({payload:a}).core.coins,30);
});
