'use strict';
const config = {columns:13,rows:15,speed:2.6,fuse:2800,fire:650,match:180000,grace:10000,
  maxRange:5,maxBombs:3,maxSpeed:1.5,drop:30};
const key=(x,y)=>`${x}_${y}`;
function hash(seed,x,y) { return ((seed ^ Math.imul(x+17,73856093) ^ Math.imul(y+31,19349663)) >>> 0); }
function board(seed, columns=config.columns, rows=config.rows, mapId=0) {
  const walls={}, crates={};
  for(let y=0;y<rows;y++) for(let x=0;x<columns;x++) {
    const k=key(x,y);
    if(x===0 || y===0 || x===columns-1 || y===rows-1 || (x%2===0 && y%2===0 && !(mapId===1 && (y===6||y===rows-7)) && !(mapId===3 && (x===4||x===columns-5)))) walls[k]=true;
    else {
      const spawn=(x<=2 && y>=rows-3)||(x>=columns-3 && y<=2);
      const mx=Math.min(x,columns-1-x),my=Math.min(y,rows-1-y);
      if(!spawn && hash(seed,mx,my)%100<[62,48,72,57][mapId]) crates[k]=true;
    }
  }
  return {columns,rows,seed,mapId,walls,crates};
}
function player() { return {alive:true,range:2,maxBombs:1,speed:1,paw:false,shieldUntil:0,immuneUntil:0,boxUntil:0,stunUntil:0}; }
function create(seed,uid,mapId=0) { return {status:'waiting',createdAt:Date.now(),board:board(seed,config.columns,config.rows,mapId),players:{[uid]:player()},bombs:{},powers:{},events:{}}; }
function blast(s,x,y,range) {
  const cells=[key(x,y)];
  for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]) for(let n=1;n<=range;n++) {
    const k=key(x+n*dx,y+n*dy); if(s.board.walls[k]) break;
    cells.push(k); if(s.board.crates[k]) break;
  }
  return cells;
}
function drop(seed,x,y,now) {
  const roll=hash(seed,x,y); if(roll%100>=config.drop) return null;
  const typeRoll=(roll>>>8)%100;
  const type=typeRoll<34?'yarn':typeRoll<59?'tuna':typeRoll<84?'fish':typeRoll<92?'box':typeRoll<98?'paw':'cake';
  return {type,x,y,availableAt:now+200};
}
function active(s,now) { return s.status==='playing' && now>=s.startsAt; }
function motionOf(m) { return {x:Number(m?.x)||1.5,y:Number(m?.y)||1.5}; }
function hit(s,motions,cells,now) {
  for(const [uid,p] of Object.entries(s.players)) {
    if (!motions[uid]) continue;
    const m=motionOf(motions[uid]);
    if(!p.alive || !cells.has(key(Math.floor(m.x),Math.floor(m.y))) || p.immuneUntil>now) continue;
    if(p.paw || p.shieldUntil>now) {
      const cake=p.shieldUntil>now;
      p.paw=false; p.shieldUntil=0; p.immuneUntil=now+800; p.stunUntil=now+300;
      if(cake) p.boxUntil=Math.max(p.boxUntil,now+2000);
    } else p.alive=false;
  }
}
function finish(s,now) {
  const alive=Object.keys(s.players).filter(u=>s.players[u].alive);
  if(Object.keys(s.players).length===2 && (alive.length<2 || now-s.startsAt>=config.match)) {
    s.status='finished'; s.result={winner:alive.length===1?alive[0]:'draw',at:now};
  }
}
function advance(s,motions={},now=Date.now()) {
  s.bombs||={};s.powers||={};s.events||={};s.board.crates||={};
  if(!active(s,now)) return s;
  const due=Object.keys(s.bombs).filter(id=>s.bombs[id].explodeAt<=now).map(id=>({id,at:s.bombs[id].explodeAt}));
  const processed=new Set();
  while(due.length) {
    due.sort((a,b)=>a.at-b.at);
    const {id,at}=due.shift(); if(processed.has(id) || !s.bombs[id]) continue;
    processed.add(id); const b=s.bombs[id],cells=blast(s,b.x,b.y,b.range);
    for(const k of cells) {
      if(s.board.crates[k]) { delete s.board.crates[k]; const [x,y]=k.split('_').map(Number);
        const power=drop(s.board.seed,x,y,at); if(power) s.powers[k]=power; }
      else if(s.powers[k] && s.powers[k].availableAt<=at) delete s.powers[k];
      for(const [other,v] of Object.entries(s.bombs)) if(other!==id && key(v.x,v.y)===k) due.push({id:other,at:Math.min(at,v.explodeAt)});
    }
    delete s.bombs[id];
    s.events[id]={cells,at,until:at+config.fire,owner:b.owner};
  }
  const flames=new Set(Object.values(s.events).filter(e=>e.until>now).flatMap(e=>e.cells));
  // Old motion can describe a tile the cat has already left during a network stall.
  const fresh=Object.fromEntries(Object.entries(motions).filter(([,m])=>!Number.isFinite(m.at)||now-m.at<=250));
  hit(s,fresh,flames,now); finish(s,now);
  for(const [id,e] of Object.entries(s.events)) if(e.until<now-30000) delete s.events[id];
  return s;
}
function place(s,uid,id,motions,now=Date.now(),requestedCell=null) {
  if(s.bombs?.[id] || s.events?.[id]) return s;
  const p=s.players[uid]; if(!active(s,now) || !p?.alive || p.stunUntil>now) throw Error('Aún no puedes colocar una bomba.');
  const m=motionOf(motions[uid]);
  let x=Math.floor(m.x),y=Math.floor(m.y);
  if(requestedCell!==null) {
    if(typeof requestedCell!=='string'||!/^\d{1,2}_\d{1,2}$/.test(requestedCell)) throw Error('Casilla de bomba inválida.');
    [x,y]=requestedCell.split('_').map(Number);
    if(Math.abs(m.x-x-.5)>1.25 || Math.abs(m.y-y-.5)>1.25) throw Error('La posición cambió. Coloca la bomba de nuevo.');
  }
  if(x<1||y<1||x>=s.board.columns-1||y>=s.board.rows-1) throw Error('Casilla de bomba inválida.');
  const k=key(x,y);
  s.bombs||={};
  if(s.board.walls[k] || s.board.crates[k] || Object.values(s.bombs).some(b=>key(b.x,b.y)===k)) throw Error('Esta casilla ya está ocupada.');
  if(Object.values(s.bombs).filter(b=>b.owner===uid).length>=p.maxBombs) throw Error('Espera a que explote tu bomba.');
  s.bombs[id]={owner:uid,x,y,range:p.range,createdAt:now,explodeAt:now+config.fuse};
  return s;
}
function pickup(s,uid,k,motions,now=Date.now()) {
  const p=s.players[uid],item=s.powers?.[k],m=motionOf(motions[uid]);
  if(!active(s,now)||!p?.alive||!item||item.availableAt>now || Math.hypot(m.x-item.x-.5,m.y-item.y-.5)>.6) return s;
  switch(item.type) {
    case 'yarn':p.range=Math.min(config.maxRange,p.range+1);break;
    case 'tuna':p.maxBombs=Math.min(config.maxBombs,p.maxBombs+1);break;
    case 'fish':p.speed=Math.min(config.maxSpeed,p.speed*1.15);break;
    case 'box':p.boxUntil=now+4000;break;
    case 'paw':p.paw=true;break;
    case 'cake':p.shieldUntil=now+5000;break;
  }
  delete s.powers[k];return s;
}
function contact(s,uid,motion,now=Date.now()) {
  if (s.status !== 'playing' || !motion || !s.players[uid]?.alive) return s;
  const at=motion.at, flames=new Set(Object.values(s.events||{})
    .filter(e=>at>=e.at && at<e.until).flatMap(e=>e.cells));
  hit(s,{[uid]:motion},flames,at);finish(s,now);return s;
}
module.exports={config,key,hash,board,player,create,blast,advance,place,pickup,drop,contact};
