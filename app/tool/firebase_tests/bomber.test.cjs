// Run only against the Firebase emulators; all players are disposable fixtures.
'use strict';
const assert=require('node:assert/strict');
const project='demo-cumplemes',dbHost=process.env.FIREBASE_DATABASE_EMULATOR_HOST;
if(!dbHost||!process.env.FIREBASE_AUTH_EMULATOR_HOST||!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Use firebase emulators:exec');
const endpoint=`http://127.0.0.1:5001/${project}/us-central1/bomberMatch`;
async function user(){const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});const d=await r.json();assert(r.ok);return {id:d.localId,token:d.idToken};}
async function api(u,action,extra={},allowed=true){const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',...(u?{Authorization:`Bearer ${u.token}`}:{})},body:JSON.stringify({action,...extra})});const d=await r.json();assert.equal(r.ok,allowed,JSON.stringify(d));return d;}
async function rt(u,path,method='GET',data,allowed=true){const admin=u==='admin';const r=await fetch(`http://${dbHost}/${path}.json?ns=${project}-default-rtdb${!admin&&u?'&auth='+u.token:''}`,{method,headers:{'Content-Type':'application/json',...(admin?{Authorization:'Bearer owner'}:{})},...(data===undefined?{}:{body:JSON.stringify(data)})});const text=await r.text();assert.equal(r.ok,allowed,`${method} ${path}: ${r.status} ${text}`);return r.ok?JSON.parse(text):null;}
async function seed(path,fields){const r=await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,{stringValue:v}]))})});assert(r.ok,await r.text());}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function main(){
  const a=await user(),b=await user(),c=await user();
  for(const [i,u] of [a,b,c].entries()){await seed('players/'+u.id,{nickname:'Test '+i});await seed('user_directory/'+u.id,{name:'Test '+i,nameKey:'test'+i});}
  await seed(`players/${a.id}/progress/current`,{payload:JSON.stringify({'rincon.v1':JSON.stringify({catCare:{maru:{outfit:{hat:'explorer'}}}})})});
  await api(null,'find',{},false);await api(a,'find',{mapId:99},false);
  const first=await api(a,'find',{mapId:1,cat:'maru'}),second=await api(b,'find',{mapId:1,cat:'nube'});
  assert.equal(first.room,second.room,'matching same arena should join the waiting room');
  const root=`bomberRooms/${first.room}`;
  let room=await rt(a,root);assert.equal(room.state.status,'ready');assert.equal(room.members[a.id].outfit.hat,'explorer');assert.equal(room.members[b.id].cat,'nube');
  await rt(c,root,'GET',undefined,false);await rt(null,root,'GET',undefined,false);
  await rt(a,root+'/state/players/'+a.id+'/range','PUT',99,false);
  await rt(a,root+'/state/bombs/forged','PUT',{range:999},false);
  await rt(a,root+'/motion/'+b.id,'PUT',room.motion[b.id],false);
  await rt(a,root+'/motion/'+a.id,'DELETE',undefined,false);
  await rt(a,root+'/presence/'+a.id,'DELETE',undefined,false);
  await api(c,'ready',{room:first.room},false);
  await api(a,'ready',{room:first.room});await api(b,'ready',{room:first.room});
  const m={...room.motion[a.id],x:1.6,vx:1,at:{'.sv':'timestamp'}};
  await rt(a,root+'/motion/'+a.id,'PUT',m,false); // countdown cannot be bypassed
  // Advance the disposable fixture's server countdown, not wall-clock sleeps.
  await rt('admin',root+'/state/startsAt','PUT',Date.now()-1000);
  await sleep(120);await rt(a,root+'/motion/'+a.id,'PUT',m);
  await rt(a,root+'/motion/'+a.id,'PUT',{...m,x:9.5,y:1.5,gx:9,gy:1,cell:'9_1'},false);
  await rt(a,root+'/motion/'+a.id,'PUT',{...m,x:2.5,y:10.5,gx:2,gy:10,cell:'2_10'},false);
  await api(a,'bomb',{room:first.room,id:'f'.repeat(32)});
  room=await rt(a,root);assert.equal(room.state.bombs['f'.repeat(32)].range,2);
  await api(a,'bomb',{room:first.room,id:'f'.repeat(32)});
  assert.equal(Object.keys((await rt(a,root)).state.bombs).length,1);
  await sleep(3200);
  room=await rt(a,root);
  assert.equal(room.state.bombs?.['f'.repeat(32)],undefined,'database trigger detonates without a client sync');
  assert(room.state.events?.['f'.repeat(32)],'server creates the flame');
  assert.equal(room.state.result.winner,b.id,'standing on the bomb loses on the server');
  // Exit, then check invitations in a different arena and with another cat.
  await api(a,'leave',{room:first.room});room=await rt(b,root);assert.equal(room.state.result.winner,b.id);
  const invite=await api(a,'invite',{target:b.id,mapId:3,cat:'milo'});
  const inbox=await rt(b,'bomberInvites/'+b.id);assert.equal(inbox[invite.room].mapId,3);
  await api(c,'accept',{room:invite.room,cat:'lady'},false);
  await rt(c,'bomberInvites/'+b.id,'GET',undefined,false);
  await api(b,'accept',{room:invite.room,cat:'lady'});
  room=await rt(b,'bomberRooms/'+invite.room);assert.equal(room.state.status,'ready');assert.equal(room.members[a.id].cat,'milo');assert.equal(room.state.board.mapId,3);
  const contactRoot='bomberRooms/'+invite.room;
  await rt('admin',contactRoot+'/state/status','PUT','playing');
  await rt('admin',contactRoot+'/state/startsAt','PUT',Date.now()-1000);
  const flameTime=Date.now();
  await rt('admin',contactRoot+'/state/events/contact','PUT',{cells:['1_11'],at:flameTime,until:flameTime+650});
  await rt(a,contactRoot+'/motion/'+a.id,'PUT',{...room.motion[a.id],x:1.6,at:{'.sv':'timestamp'}});
  for(let n=0;n<20;n++){room=await rt(a,contactRoot);if(room.state.result)break;await sleep(100);}
  assert.equal(room.state.result?.winner,b.id,'motion trigger catches contact with an existing flame');
  await api(b,'leave',{room:invite.room});await api(a,'leave',{room:invite.room});
  const declined=await api(a,'invite',{target:c.id,mapId:2,cat:'lady'});
  await api(c,'decline',{room:declined.room});assert.equal(await rt(c,'bomberInvites/'+c.id+'/'+declined.room),null);
  await api(a,'leave',{room:declined.room});
  console.log('Bomber emulator checks passed: matching, invitations, outfits, countdown, own motion, denied teleports/deletions/forged stats and authoritative bombs/results.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
