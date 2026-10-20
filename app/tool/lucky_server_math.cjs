'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {inspectConfiguration}=require('../functions/economy_v2/casino/math.cjs');
const {rulesHash,getConfig}=require('../functions/economy_v2/casino/engine.cjs');
const expected=require('./lucky_server_parity.json');
const report={};
for(const id of ['reference25','scaled10']){
  const actual=inspectConfiguration(id);
  assert.equal(actual.roundsSha256,expected[id].roundsSha256);
  assert.deepEqual(actual.histogram,expected[id].histogram);
  report[id]={...actual,rulesHash:rulesHash(getConfig(id)),dartParity:true};
}
fs.writeFileSync(require('node:path').join(__dirname,'lucky_server_math.json'),JSON.stringify(report,null,2)+'\n');
console.log(Object.fromEntries(Object.entries(report).map(([id,r])=>[id,{rtp:r.rtp,maxRound:r.maxRound,maxCycle:r.maxCycle,dartParity:r.dartParity}])));
