'use strict';
const {digest}=require('../common.cjs');
const data=require('./rules.json');
function freeze(v){if(v&&typeof v==='object'){Object.values(v).forEach(freeze);Object.freeze(v);}return v;}
const configs=freeze(data);
const symbols=['yarn','fish','churu','bell','maru','lady','seven','wild','scatter'];
function getConfig(id){return Object.hasOwn(configs,id)?configs[id]:null;}
function rulesHash(rules){return digest(rules);}
function evaluateLine(values,rules,line=rules.lines[1]) {
  if(values.length!==5||values.some(s=>!symbols.includes(s))) throw Error('invalid line');
  let best=null;
  for(const symbol of symbols) {
    const pay=rules.payouts[symbol];if(!pay)continue;
    let count=0;
    for(const value of values){if(value!==symbol&&(value!=='wild'||symbol==='wild'))break;count++;}
    const multiplier=pay[count];if(multiplier===undefined)continue;
    const amount=multiplier*rules.lineStake;
    if(!best||amount>best.amount||amount===best.amount&&count>best.count)best={id:line.id,symbol,count,multiplier,amount};
  }
  return best;
}
function evaluateGrid(grid,rules) {
  if(grid.length!==15||grid.some(s=>!symbols.includes(s)))throw Error('invalid grid');
  const lines=[],scatterColumns=[];
  for(const line of rules.lines){const win=evaluateLine(line.rows.map((r,c)=>grid[r*5+c]),rules,line);if(win)lines.push(win);}
  for(let c=0;c<5;c++)if([0,1,2].some(r=>grid[r*5+c]==='scatter'))scatterColumns.push(c);
  return {lines,scatterColumns,amount:lines.reduce((n,w)=>n+w.amount,0)};
}
function evaluateStops(stops,rules,bonus={remaining:0,awarded:0}) {
  if(!Number.isInteger(bonus.remaining)||!Number.isInteger(bonus.awarded)||bonus.remaining<0||bonus.awarded<bonus.remaining||bonus.awarded>rules.maxBonusSpins)throw Error('invalid bonus');
  if(stops.length!==5||stops.some((n,c)=>!Number.isInteger(n)||n<0||n>=rules.reels[c].length))throw Error('invalid stops');
  const grid=Array.from({length:15},(_,i)=>rules.reels[i%5][(stops[i%5]+Math.floor(i/5))%rules.reels[i%5].length]);
  const evaluated=evaluateGrid(grid,rules),freeSpin=bonus.remaining>0,awarded=freeSpin?bonus.awarded:0;
  const requestedSpins=rules.scatterAwards[evaluated.scatterColumns.length]||0;
  const grantedSpins=Math.min(requestedSpins,rules.maxBonusSpins-awarded);
  // Field order intentionally matches LuckyRound.toJson for cross-runtime SHA256.
  return {catalogVersion:rules.catalogVersion,rulesVersion:rules.rulesVersion,stops:[...stops],grid,
    amount:evaluated.amount,freeSpin,simulatedCost:freeSpin?0:rules.lineStake*5,
    scatterColumns:evaluated.scatterColumns,grantedSpins,
    remaining:(freeSpin?bonus.remaining-1:0)+grantedSpins,awarded:awarded+grantedSpins,lines:evaluated.lines};
}
module.exports={getConfig,configs,symbols,rulesHash,evaluateLine,evaluateGrid,evaluateStops};
