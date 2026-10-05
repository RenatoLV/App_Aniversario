'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const E=require('../bomber_engine.cjs');
function match(){const s=E.create(42,'a');s.board=E.board(42,11,13);s.players.b=E.player();s.status='playing';s.startsAt=0;return s;}
const safe={a:{x:1.5,y:11.5},b:{x:9.5,y:1.5}};
test('four maps are symmetric and both spawns can escape',()=>{
  const maps=[];for(let id=0;id<4;id++){const b=E.board(42,11,13,id);maps.push(JSON.stringify([b.walls,b.crates]));
    for(const k of Object.keys(b.crates)){const [x,y]=k.split('_').map(Number);assert.equal(b.crates[E.key(10-x,12-y)],true);}
    for(const k of ['1_11','1_10','2_11','9_1','8_1','9_2'])assert.equal(b.crates[k]||b.walls[k],undefined);
  }assert.equal(new Set(maps).size,4);
});
test('cross stops at walls and the first crate',()=>{
  const s=match();s.board.walls={'5_3':true};s.board.crates={'3_5':true};
  const cells=E.blast(s,3,3,5);assert(cells.includes('3_5'));assert(!cells.includes('3_6'));assert(!cells.includes('5_3'));assert(!cells.includes('6_3'));
});
test('bomb retries do not duplicate and range/count are server-owned',()=>{
  const s=match();E.place(s,'a','one',safe,100);E.place(s,'a','one',safe,101);
  assert.equal(Object.keys(s.bombs).length,1);assert.equal(s.bombs.one.range,2);
  assert.throws(()=>E.place(s,'a','two',safe,101),/ocupada|bomba/);
});
test('chain explosions destroy crates and leave players outside fire alive',()=>{
  const s=match();s.board.walls={};s.board.crates={'4_3':true};
  s.bombs={one:{x:1,y:3,range:2,owner:'a',explodeAt:10},two:{x:3,y:3,range:3,owner:'b',explodeAt:9999}};
  E.advance(s,safe,10);assert.equal(Object.keys(s.bombs).length,0);assert.equal(Object.keys(s.events).length,2);
  assert.equal(s.board.crates['4_3'],undefined);assert(!s.events.two.cells.includes('5_3'));assert.equal(s.players.a.alive,true);
});
test('six powers apply once and stack only up to their caps',()=>{
  const s=match(),m={a:{x:1.5,y:11.5}};
  for(const type of ['yarn','tuna','fish','box','paw','cake'])for(let n=0;n<10;n++){
    s.powers['1_11']={type,x:1,y:11,availableAt:1};E.pickup(s,'a','1_11',m,100);
    assert.equal(s.powers['1_11'],undefined);
  }const p=s.players.a;assert.equal(p.range,5);assert.equal(p.maxBombs,3);assert.equal(p.speed,1.5);
  assert.equal(p.boxUntil,4100);assert.equal(p.paw,true);assert.equal(p.shieldUntil,5100);
});
test('walking into a lingering flame is lethal even when motion delivery is delayed',()=>{
  const s=match();s.events.one={cells:['1_11'],at:1000,until:1650};
  E.contact(s,'a',{x:1.5,y:11.5,at:1400},2500);assert.equal(s.players.a.alive,false);assert.equal(s.result.winner,'b');
  const untouched=match();untouched.events.one=s.events.one;E.contact(untouched,'a',{x:1.5,y:11.5,at:900},2500);assert.equal(untouched.players.a.alive,true);
});
test('shield absorbs a hit, grants recovery and clears only once',()=>{
  const s=match();s.players.a.shieldUntil=6000;s.events.one={cells:['1_11'],at:1000,until:2000};
  E.contact(s,'a',{x:1.5,y:11.5,at:1400},1400);assert.equal(s.players.a.alive,true);assert.equal(s.players.a.shieldUntil,0);
  assert.equal(s.players.a.immuneUntil,2200);assert.equal(s.players.a.boxUntil,3400);
  E.contact(s,'a',{x:1.5,y:11.5,at:1500},1500);assert.equal(s.players.a.alive,true);
});
test('simultaneous death and time expiry produce a draw',()=>{
  const s=match();s.events.one={cells:['1_11','9_1'],at:10,until:1000};E.advance(s,safe,100);assert.equal(s.result.winner,'draw');
  const timeout=match();E.advance(timeout,safe,E.config.match);assert.equal(timeout.result.winner,'draw');
});

test('larger arenas preserve symmetry and open starting corridors',()=>{
 for(let map=0;map<4;map++) {
  const b=E.create(42,'a',map).board;
  assert.equal(b.columns,13);assert.equal(b.rows,15);
  for(const k of Object.keys(b.crates)){const [x,y]=k.split('_').map(Number);assert.equal(b.crates[E.key(12-x,14-y)],true);}
  for(const k of Object.keys(b.walls)){const [x,y]=k.split('_').map(Number);assert.equal(b.walls[E.key(12-x,14-y)],true);}
  for(const k of ['1_13','1_12','2_13','11_1','10_1','11_2'])assert.equal(b.crates[k]||b.walls[k],undefined);
 }
});
test('delayed bomb uses tap cell rather than newer motion and rejects distant cells',()=>{
 const s=match();s.board.crates={};
 E.place(s,'a','tap',{a:{x:2.1,y:11.5}},100,'1_11');
 assert.equal(s.bombs.tap.x,1);assert.equal(s.bombs.tap.y,11);
 const other=match();other.board.crates={};
 assert.throws(()=>E.place(other,'a','far',safe,100,'7_11'),/posición/);
 assert.throws(()=>E.place(other,'a','outside',safe,100,'0_11'),/inválida/);
});
