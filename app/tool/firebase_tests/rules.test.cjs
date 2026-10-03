// Integration tests use emulators and Node's fetch only. Never targets production.
const assert = require('node:assert/strict');
const project = 'demo-cumplemes';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Run through firebase emulators:exec');
async function user() {
  const response = await fetch('http://'+process.env.FIREBASE_AUTH_EMULATOR_HOST+'/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});
  const body = await response.json();
  assert.equal(response.status,200,JSON.stringify(body));
  return {id:body.localId,token:body.idToken};
}
function fields(data) { return Object.fromEntries(Object.entries(data).map(([k,v])=>[k,v===null?{nullValue:null}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v}:{stringValue:v}])); }
async function stamped(who,path,data,time='updatedAt',allowed=true) {
  const response=await fetch('http://'+host+'/v1/projects/'+project+'/databases/(default)/documents:commit',{
    method:'POST',headers:{Authorization:'Bearer '+who.token,'Content-Type':'application/json'},
    body:JSON.stringify({writes:[{update:{name:'projects/'+project+'/databases/(default)/documents/'+path,fields:fields(data)},
      updateTransforms:[{fieldPath:time,setToServerValue:'REQUEST_TIME'}]}]})});
  assert.equal(response.ok,allowed,path+' '+response.status+' '+await response.text());
}
async function doc(who, path, data, allowed=true) {
  const response = await fetch('http://'+host+'/v1/projects/'+project+'/databases/(default)/documents/'+path, {
    method:data?'PATCH':'GET', headers:{'Content-Type':'application/json',...(who?{Authorization:'Bearer '+who.token}:{})},
    ...(data?{body:JSON.stringify({fields:fields(data)})}:{})
  });
  const body = await response.text();
  assert.equal(response.ok,allowed, path+' '+response.status+' '+body);
}
async function realtime(who,path,data,allowed=true) {
  const response=await fetch('http://'+process.env.FIREBASE_DATABASE_EMULATOR_HOST+'/'+path+'.json?ns='+project+'-default-rtdb&auth='+who.token, {
    method:data===undefined?'GET':'PUT',headers:{'Content-Type':'application/json'},...(data===undefined?{}:{body:JSON.stringify(data)})
  });
  assert.equal(response.ok,allowed,path+' '+response.status+' '+await response.text());
}
async function storage(who, name, upload, allowed=true, type='image/png') {
  const base='http://'+process.env.FIREBASE_STORAGE_EMULATOR_HOST+'/v0/b/'+project+'.appspot.com/o';
  const boundary = 'firebase_test_boundary';
  const body = '--'+boundary+'\r\nContent-Type: application/json; charset=utf-8\r\n\r\n'+JSON.stringify({name,contentType:type})+'\r\n--'+boundary+'\r\nContent-Type: '+type+'\r\n\r\nPNG-test\r\n--'+boundary+'--';
  const response=await fetch(upload?base+'?uploadType=multipart&name='+encodeURIComponent(name):base+'/'+encodeURIComponent(name), {
    method:upload?'POST':'GET',headers:{Authorization:'Firebase '+who.token,'Content-Type':upload?'multipart/related; boundary='+boundary:type,...(upload?{'x-goog-upload-protocol':'multipart'}:{})},...(upload?{body}:{})
  });
  assert.equal(response.ok,allowed,name+' '+response.status+' '+await response.text());
}
async function main(){
  const a=await user(), b=await user();
  const c=await user();
  const atomicRoom='abcdefghijklmnopqrst';
  const atomic=await fetch('http://'+host+'/v1/projects/'+project+'/databases/(default)/documents:commit', {
    method:'POST',headers:{Authorization:'Bearer '+c.token,'Content-Type':'application/json'},
    body:JSON.stringify({writes:[
      ['spaces/'+atomicRoom,{owner:c.id}],
      ['spaces/'+atomicRoom+'/members/'+c.id,{nickname:'C'}],
      ['players/'+c.id,{spaceId:atomicRoom,nickname:'C'}],
    ].map(([path,data])=>({update:{name:'projects/'+project+'/databases/(default)/documents/'+path,fields:fields(data)}}))})
  });
  assert.equal(atomic.ok,true,'Atomic profile and room creation '+await atomic.text());
  const room='12345678901234567890', prefix='spaces/'+room;
  await doc(a,'players/'+a.id+'/progress/current',{revision:1,payload:'{}'});
  await doc(b,'players/'+a.id+'/progress/current',null,false);
  await doc(null,'players/'+a.id+'/progress/current',null,false);
  await doc(a,'players/'+a.id+'/progress/current',{revision:1,payload:'stale'},false);
  await doc(a,'players/'+a.id+'/progress/current',{revision:2,payload:'updated'});
  await doc(a,prefix,{owner:a.id});
  await doc(a,prefix+'/members/'+a.id,{nickname:'A'});
  await stamped(a,'user_directory/'+a.id,{name:'A',nameKey:'a'},'lastSeen');
  await stamped(b,'user_directory/'+b.id,{name:'B',nameKey:'b'},'lastSeen');
  await stamped(b,'user_directory/'+a.id,{name:'Forged',nameKey:'forged'},'lastSeen',false);
  await doc(b,'user_directory/'+a.id);
  await doc(null,'user_directory/'+a.id,null,false);
  await stamped(a,'user_directory/'+a.id,{name:'A',nameKey:'a',email:'private'},'lastSeen',false);
  const requestPath='bloc_requests/'+a.id+'_'+b.id;
  const request={fromUid:b.id,toUid:a.id,name:'B',status:'pending',spaceId:null};
  await stamped(b,requestPath,request);
  await doc(a,requestPath);await doc(b,requestPath);await doc(c,requestPath,null,false);
  await stamped(b,requestPath,{...request,status:'accepted',spaceId:room},'updatedAt',false);
  await stamped(a,requestPath,{...request,status:'accepted',spaceId:atomicRoom},'updatedAt',false);
  await stamped(a,requestPath,{...request,status:'rejected'});
  await stamped(b,requestPath,request);
  await stamped(a,requestPath,{...request,status:'accepted',spaceId:room});
  await stamped(a,requestPath,{...request,status:'pending',spaceId:null},'updatedAt',false);
  await stamped(b,requestPath,request,'updatedAt',false);
  async function query(who, collectionId, field, value, allowed = true) {
    const structuredQuery={from:[{collectionId}],...(field?{where:{fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:{stringValue:value}}}}:{orderBy:[{field:{fieldPath:'nameKey'},direction:'ASCENDING'}]})};
    const result=await fetch('http://'+host+'/v1/projects/'+project+'/databases/(default)/documents:runQuery',{
      method:'POST',headers:{Authorization:'Bearer '+who.token,'Content-Type':'application/json'},body:JSON.stringify({structuredQuery})});
    assert.equal(result.ok,allowed,'Query permission '+collectionId+': '+await result.text());
  }
  await query(a,'user_directory');
  await query(b,'bloc_requests','fromUid',b.id);
  await query(a,'bloc_requests','toUid',a.id);
  await query(c,'bloc_requests','fromUid',b.id,false);
  const note={body:'hola',x:.1,y:.2,scale:1,mediaKind:null,mediaPath:null,editor:a.id,updatedAt:'now'};
  await doc(a,prefix+'/notes/one',note);
  await doc(a,prefix+'/notes/deleted',{...note,deleted:true});
  await doc(a,prefix+'/notes/deleted',{...note,deleted:false});
  await doc(b,prefix+'/notes/one',null,false);
  await doc(b,prefix+'/members/'+a.id,{nickname:'forged'},false);
  await storage(a,prefix+'/notes/one/image',true);
  await storage(a,prefix+'/notes/photo/jpeg',true,true,'image/jpeg');
  await doc(a,prefix+'/notes/photo',{...note,body:'foto creada antes de iniciar sesión',mediaKind:'photo',mediaPath:prefix+'/notes/photo/jpeg'});
  await storage(b,prefix+'/notes/one/image',false,false);
  await storage(a,prefix+'/notes/one/bad',true,false,'text/html');
  await doc(b,prefix+'/members/'+b.id,{nickname:'B'});
  await doc(b,prefix+'/notes/one');
  await storage(b,prefix+'/notes/one/image',false);
  await storage(b,prefix+'/notes/photo/jpeg',false);
  await doc(b,prefix+'/notes/photo');
  await doc(b,prefix+'/notes/one',{...note,body:'editado',editor:b.id});
  await doc(b,prefix+'/notes/one',{...note,editor:b.id,mediaPath:'spaces/other/secret'},false);
  const score={user_id:a.id,nickname:'A',game:'blocks-v1',score:100,updated_at:'now'};
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',score);
  await doc(b,prefix+'/scores/'+a.id+'_blocks-v1',{...score,user_id:b.id},false);
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',{...score,score:50},false);
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',{...score,score:150});
  // Rankings are shared across users, independently of mural membership.
  await doc(a,'game_scores/'+a.id+'_blocks-v1',score);
  await doc(c,'game_scores/'+a.id+'_blocks-v1');
  await doc(null,'game_scores/'+a.id+'_blocks-v1',null,false);
  await doc(b,'game_scores/'+a.id+'_blocks-v1',{...score,user_id:b.id},false);
  await doc(a,'game_scores/'+a.id+'_blocks-v1',{...score,score:50},false);
  await doc(a,'game_scores/'+a.id+'_blocks-v1',{...score,score:200});
  await doc(a,'game_scores/'+a.id+'_blocks-v1',{...score,score:200,nickname:'Nuevo nombre'});
  for (const game of ['wordlady','candy-churu-cat','ascenso-maruzon']) {
    await doc(c,'game_scores/'+c.id+'_'+game,{...score,user_id:c.id,nickname:'C',game});
    await doc(b,'game_scores/'+c.id+'_'+game);
  }
  await doc(a,'game_scores/'+a.id+'_invalid',{...score,game:'invalid'},false);
  await realtime(a,prefix+'/members/'+a.id,true);
  await realtime(b,prefix+'/presence',undefined,false);
  await realtime(a,prefix+'/presence/'+a.id+'/device',{name:'A',since:1});
  await realtime(b,prefix+'/presence/'+a.id+'/device',null,false);
  await realtime(b,prefix+'/members/'+b.id,true);
  await realtime(b,prefix+'/presence');
  console.log('PASS: private progress, stale revisions, mural invitations, images, presence and impersonation.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
