'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fs=require('node:fs'),path=require('node:path');
const fixtures=require('../../tool/lucky_server_parity.json');
const {configs,getConfig,evaluateStops,evaluateLine,symbols,rulesHash}=require('../economy_v2/casino/engine.cjs');
const {inspectConfiguration}=require('../economy_v2/casino/math.cjs');
const {createRandom,uniform}=require('../economy_v2/casino/rng.cjs');
const {decodeKeyring}=require('../economy_v2/casino/keys.cjs');
for(const configId of Object.keys(configs)){
  test(`server/Dart parity: all 16^5 outcomes, exact joint distribution, RTP and fixtures ${configId}`,()=>{
    const actual=inspectConfiguration(configId),expected=fixtures[configId];
    assert.equal(actual.roundsSha256,expected.roundsSha256);assert.deepEqual(actual.histogram,expected.histogram);
    assert.equal(actual.stopsCount,expected.stopsCount);assert.ok(Math.abs(actual.rtp-0.9078688024966274)<1e-12);
    assert.equal(actual.maxCycle,configId==='reference25'?142820:57128);
    for(const fixture of expected.fixtures)assert.deepEqual(evaluateStops(fixture.round.stops,getConfig(configId),fixture.before),fixture.round);
  });
}
test('server/Dart parity: all 59049 single lines including ambiguous Wild and Scatter',()=>{
  const hash=crypto.createHash('sha256');
  for(let n=0;n<59049;n++){
    let value=n;const line=Array(5);
    for(let c=4;c>=0;c--){line[c]=symbols[value%9];value=Math.floor(value/9);}
    hash.update(JSON.stringify(evaluateLine(line,getConfig('reference25')))+'\n');
  }
  assert.equal(hash.digest('hex'),fixtures.lines.sha256);
});
test('crypto: stable canonical context, epoch, UID, operation, nonce and domain isolation',()=>{
  const key=Buffer.alloc(32,11),context={ownerUid:'alice',operationId:'a'.repeat(32),sequence:1,keyEpoch:'test1',rulesHash:rulesHash(getConfig('reference25'))};
  const sequence=ctx=>{const r=createRandom(key,ctx);return Array.from({length:32},()=>r.nextInt(2147483649));};
  const before=sequence(context);
  assert.deepEqual(sequence(Object.fromEntries(Object.entries(context).reverse())),before);
  for(const patch of [{ownerUid:'bob'},{operationId:'b'.repeat(32)},{sequence:2},{keyEpoch:'test2'},{rulesHash:'other'}])assert.notDeepEqual(sequence({...context,...patch}),before);
  assert.notDeepEqual(sequence(context),(()=>{const r=createRandom(Buffer.alloc(32,12),context);return Array.from({length:32},()=>r.nextInt(2147483649));})());
  assert.throws(()=>createRandom(Buffer.alloc(12),context));
});
test('crypto: explicit rejection sampling discards upper incomplete interval',()=>{
  const words=[0xffffffff,0xfffffffe,29];
  assert.equal(uniform(()=>words.shift(),10),9);assert.equal(words.length,0);
  for(const n of [0,-1,1.5,0x100000001])assert.throws(()=>uniform(()=>0,n));
  assert.equal(uniform(()=>0xffffffff,0x100000000),0xffffffff);
});
test('engine: immutable versions, bonus reset/cap and validated ranges',()=>{
  const rules=getConfig('reference25'),scatter=[14,6,3,9,10];
  assert.equal(evaluateStops(scatter,rules,{remaining:1,awarded:49}).grantedSpins,1);
  assert.equal(evaluateStops(scatter,rules,{remaining:50,awarded:50}).grantedSpins,0);
  assert.equal(evaluateStops(scatter,rules,{remaining:0,awarded:50}).awarded,12);
  assert.throws(()=>evaluateStops(scatter,rules,{remaining:2,awarded:1}));
  assert.throws(()=>evaluateStops([16,0,0,0,0],rules));
  assert.notEqual(rulesHash(rules),rulesHash(getConfig('scaled10')));
  assert.throws(()=>{rules.reels[0][0]='scatter';});
});
test('secret provider: no fallback key, missing/invalid epochs reject and archive epochs remain available',()=>{
  const json=JSON.stringify({epoch1:'01'.repeat(32),epoch2:'02'.repeat(32)});
  const options=decodeKeyring(json,'epoch2');assert.equal(options.currentEpoch,'epoch2');assert.equal(options.keyring.epoch1.length,32);
  assert.throws(()=>decodeKeyring(json,'epoch3'));assert.throws(()=>decodeKeyring('{}','epoch1'));
  assert.throws(()=>decodeKeyring('{"epoch1":"public-seed"}','epoch1'));
  assert.throws(()=>decodeKeyring(JSON.stringify({constructor:'01'.repeat(32)}),'constructor'));
});
test('server has no imports of fixed-outcome adapters, random APIs or historical wallet',()=>{
  const folder=path.join(__dirname,'../economy_v2/casino');
  for(const name of ['service.cjs','rng.cjs','engine.cjs']){
    const text=fs.readFileSync(path.join(folder,name),'utf8');
    assert.doesNotMatch(text,/Math\.random|stage4a-harness|rincon\.v1|Park.Miller/);
  }
});
