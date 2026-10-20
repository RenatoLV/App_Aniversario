'use strict';
const crypto=require('node:crypto');
const {getConfig,evaluateStops}=require('./engine.cjs');
function inspectConfiguration(configId) {
  const rules=getConfig(configId),hash=crypto.createHash('sha256'),histogram={},counts=Array(6).fill(0),sums=Array(6).fill(0),maxima=Array(6).fill(0);
  for(let n=0;n<1048576;n++){
    const round=evaluateStops(Array.from({length:5},(_,c)=>(n>>>(4*(4-c)))&15),rules);
    hash.update(JSON.stringify(round)+'\n');
    const c=round.scatterColumns.length,key=`${round.amount}:${c}`;
    histogram[key]=(histogram[key]||0)+1;counts[c]++;sums[c]+=round.amount;maxima[c]=Math.max(maxima[c],round.amount);
  }
  const population=1048576,mean=sums.reduce((a,b)=>a+b,0)/population,memo=new Map();
  function future(remaining,awarded){
    if(!remaining)return {mean:0,max:0};
    const key=`${remaining}:${awarded}`;if(memo.has(key))return memo.get(key);
    let m=mean,max=0;
    for(let c=0;c<6;c++){
      if(!counts[c])continue;
      const grant=Math.min(rules.scatterAwards[c]||0,rules.maxBonusSpins-awarded);
      const next=future(remaining-1+grant,awarded+grant);
      m+=counts[c]/population*next.mean;max=Math.max(max,maxima[c]+next.max);
    }
    const value={mean:m,max};memo.set(key,value);return value;
  }
  let cycleMean=mean,cycleMax=0;
  for(let c=0;c<6;c++){
    const grant=rules.scatterAwards[c]||0,next=future(grant,grant);
    cycleMean+=counts[c]/population*next.mean;cycleMax=Math.max(cycleMax,maxima[c]+next.max);
  }
  return {configId,stopsCount:population,roundsSha256:hash.digest('hex'),histogram,scatterCounts:counts,
    meanRound:mean,cycleMean,rtp:cycleMean/(rules.lineStake*5),maxRound:Math.max(...maxima),maxCycle:cycleMax};
}
module.exports={inspectConfiguration};
