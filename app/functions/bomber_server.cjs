'use strict';
const {onRequest}=require('firebase-functions/v2/https');
const {onValueCreated,onValueWritten}=require('firebase-functions/v2/database');
const {getAuth}=require('firebase-admin/auth');
const {getDatabaseWithUrl}=require('firebase-admin/database');
const {getFirestore}=require('firebase-admin/firestore');
const crypto=require('node:crypto'),E=require('./bomber_engine.cjs');
const instance=`${process.env.GCLOUD_PROJECT||'cumplemes'}-default-rtdb`;
const database=()=>getDatabaseWithUrl(`https://${instance}.firebaseio.com`);
const room=id=>database().ref(`bomberRooms/${id}`);
const validRoom=id=>typeof id==='string'&&/^[-\w]{10,80}$/.test(id);
async function member(uid,cat) {
  if(!['maru','lady','milo','nube'].includes(cat)) throw Error('Elige un gatito válido.');
  const [profile,saved]=await Promise.all([getFirestore().doc(`players/${uid}`).get(),getFirestore().doc(`players/${uid}/progress/current`).get()]);
  let care={};try {care=JSON.parse(JSON.parse(saved.data()?.payload||'{}')['rincon.v1']||'{}').catCare||{};} catch (_) {}
  return {name:(profile.data()?.nickname||'Gatito').slice(0,40),cat,outfit:care[cat]?.outfit||{}};
}
function motion(first,board) {const x=first?1.5:board.columns-1.5,y=first?board.rows-1.5:1.5;return {x,y,gx:Math.floor(x),gy:Math.floor(y),cell:E.key(Math.floor(x),Math.floor(y)),vx:0,vy:0,at:Date.now()};}
async function join(id,uid,kitten) {
  const joined=await room(id).transaction(data=>{
    if(!data) return data; // A cold RTDB transaction retries with the server value.
    if(data.state.status!=='waiting'||Date.now()-data.state.createdAt>60000||data.members[uid]||Object.keys(data.members).length!==1) return;
    if(data.invitedUid&&data.invitedUid!==uid) return;
    data.members[uid]=kitten;data.state.players[uid]=E.player();data.state.status='ready';
    data.motion[uid]=motion(false,data.state.board);data.presence[uid]={online:true,at:Date.now()};return data;
  });
  if(!joined.committed||!joined.snapshot.child('members').child(uid).exists()) throw Error('La invitación expiró o la sala ya está ocupada.');
  await database().ref(`bomberUsers/${uid}/room`).set(id);
}
async function settle(id,action) {
  const ref=room(id),snapshot=(await ref.get()).val();if(!snapshot) return;
  const now=Date.now(),motions=snapshot.motion||{};
  return ref.child('state').transaction(s=>{
    if(!s) return s; E.advance(s,motions,now);
    if(s.status==='playing'&&now>=s.startsAt) {
      const missing=Object.keys(s.players).filter(uid=>snapshot.presence?.[uid]?.online===false&&now-(snapshot.presence[uid].at||0)>E.config.grace);
      if(missing.length) {s.status='abandoned';s.result={winner:missing.length===1?Object.keys(s.players).find(u=>u!==missing[0]):'draw',at:now};}
    }
    if(action) action(s,motions,now);return s;
  });
}
exports.bomberMatch=onRequest({region:'us-central1',cors:true,maxInstances:4,memory:'256MiB',timeoutSeconds:30},async(req,res)=>{
  if(req.method!=='POST') return res.status(405).json({error:'Usa POST.'});
  try {
    const token=(req.get('Authorization')||'').match(/^Bearer (.+)$/)?.[1];if(!token) return res.status(401).json({error:'Inicia sesión con Google.'});
    const {uid}=await getAuth().verifyIdToken(token),input=req.body||{},rtdb=database();
    if(['find','invite','accept'].includes(input.action)) {
      const assigned=(await rtdb.ref(`bomberUsers/${uid}/room`).get()).val();
      if(validRoom(assigned)) {
        const old=(await room(assigned).child('state').get()).val();
        if(old&&!['finished','abandoned'].includes(old.status)&&Date.now()-old.createdAt<240000) {
          if(input.action==='find') return res.json({room:assigned});throw Error('Termina o cancela tu partida anterior.');
        }
      }
      const kitten=await member(uid,input.cat||'maru');
      if(input.action==='accept') {
        if(!validRoom(input.room)) throw Error('Invitación inválida.');
        const invite=rtdb.ref(`bomberInvites/${uid}/${input.room}`),data=(await invite.get()).val();
        if(!data||data.until<Date.now()) throw Error('Esta invitación expiró.');
        await join(input.room,uid,kitten);await invite.remove();return res.json({room:input.room});
      }
      const mapId=input.mapId??0;if(!Number.isInteger(mapId)||mapId<0||mapId>3) throw Error('Arena inválida.');
      if(input.action==='invite'&&(typeof input.target!=='string'||input.target===uid||!/^[\w-]{1,128}$/.test(input.target)||(await getFirestore().doc(`user_directory/${input.target}`).get()).exists===false)) throw Error('Jugador no disponible.');
      const myRoom=room(rtdb.ref('bomberRooms').push().key),seed=crypto.randomInt(0,2147483647);
      await myRoom.set({members:{[uid]:kitten},state:E.create(seed,uid,mapId),motion:{[uid]:motion(true,E.board(seed,E.config.columns,E.config.rows,mapId))},presence:{[uid]:{online:true,at:Date.now()}},...(input.action==='invite'?{invitedUid:input.target}:{})});
      let chosen=myRoom.key;
      if(input.action==='invite') await rtdb.ref(`bomberInvites/${input.target}/${chosen}`).set({room:chosen,name:kitten.name,fromUid:uid,mapId,until:Date.now()+60000});
      else {
        let candidate=null;const lobby=rtdb.ref(`bomberLobby/${mapId}`);
        await lobby.transaction(slot=>{candidate=null;if(slot&&slot.uid!==uid&&slot.until>Date.now()) {candidate=slot;return null;}return {uid,room:myRoom.key,until:Date.now()+60000};});
        if(candidate) {
          try {await join(candidate.room,uid,kitten);chosen=candidate.room;await myRoom.remove();}
          catch (_) {await lobby.transaction(slot=>slot||{uid,room:myRoom.key,until:Date.now()+60000});}
        }
      }
      await rtdb.ref(`bomberUsers/${uid}/room`).set(chosen);return res.json({room:chosen});
    }
    if(input.action==='decline') {if(!validRoom(input.room)) throw Error('Invitación inválida.');await rtdb.ref(`bomberInvites/${uid}/${input.room}`).remove();return res.json({ok:true});}
    if(!validRoom(input.room)) throw Error('Sala inválida.');
    const ref=room(input.room),data=(await ref.get()).val();if(!data?.members?.[uid]) throw Error('No perteneces a esta partida.');
    if(input.action==='ready') {
      await ref.child('state').transaction(s=>{
        if(!s||!['ready','waiting'].includes(s.status)) return s;s.ready||={};s.ready[uid]=true;
        if(Object.keys(s.players).length===2&&Object.keys(s.players).every(u=>s.ready[u])) {s.status='playing';s.startsAt=Date.now()+3000;}return s;
      });
    } else if(input.action==='bomb') {
      if(typeof input.id!=='string'||!/^[a-f0-9]{32}$/.test(input.id)) throw Error('Bomba inválida.');await settle(input.room,(s,m,n)=>E.place(s,uid,input.id,m,n,input.cell??null));
    } else if(input.action==='pickup') {
      if(typeof input.cell!=='string'||!/^\d{1,2}_\d{1,2}$/.test(input.cell)) throw Error('Poder inválido.');await settle(input.room,(s,m,n)=>E.pickup(s,uid,input.cell,m,n));
    } else if(input.action==='sync') {
      await settle(input.room,(s,_,now)=>{if(['waiting','ready'].includes(s.status)&&now-s.createdAt>60000) {s.status='abandoned';s.result={winner:'draw',at:now};}});
    } else if(input.action==='leave') {
      await ref.child('state').transaction(s=>{if(!s||['finished','abandoned'].includes(s.status)) return s;s.status='abandoned';s.result={winner:Object.keys(s.players).find(u=>u!==uid)||'draw',at:Date.now()};return s;});
      await rtdb.ref(`bomberLobby/${data.state.board.mapId||0}`).transaction(slot=>slot?.uid===uid?null:slot);
      if(data.invitedUid) await rtdb.ref(`bomberInvites/${data.invitedUid}/${input.room}`).remove();
    } else throw Error('Acción inválida.');
    return res.json({ok:true});
  } catch(error) {const auth=String(error.code||'').startsWith('auth/');res.status(auth?401:400).json({error:auth?'Vuelve a iniciar sesión.':error.message});}
});
exports.bomberBomb=onValueCreated({ref:'/bomberRooms/{room}/state/bombs/{bomb}',instance,region:'us-central1',maxInstances:6,memory:'256MiB',timeoutSeconds:30,retry:true},async event=>{
  const bomb=event.data.val();await new Promise(resolve=>setTimeout(resolve,Math.max(0,Math.min(E.config.fuse,bomb.explodeAt-Date.now()))));await settle(event.params.room);
});
// Timestamped motion catches a cat walking into a blast after detonation,
// including an event delivered after the short visual flame has faded.
exports.bomberContact=onValueWritten({ref:'/bomberRooms/{room}/motion/{uid}',instance,region:'us-central1',maxInstances:6,memory:'256MiB',timeoutSeconds:30,retry:true},async event=>{
  const motion=event.data.after.val();if(!motion) return;
  const stateRef=room(event.params.room).child('state'),s=(await stateRef.get()).val();
  if(!s||s.status!=='playing'||!Object.values(s.events||{}).some(e=>motion.at>=e.at&&motion.at<e.until)) return;
  await stateRef.transaction(current=>current?E.contact(current,event.params.uid,motion):current);
});
