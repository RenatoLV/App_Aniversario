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
function fields(data) { return Object.fromEntries(Object.entries(data).map(([k,v])=>[k,v===null?{nullValue:null}:typeof v==='number'?Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v}:{stringValue:v}])); }
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
  const note={body:'hola',x:.1,y:.2,scale:1,mediaKind:null,mediaPath:null,editor:a.id,updatedAt:'now'};
  await doc(a,prefix+'/notes/one',note);
  await doc(b,prefix+'/notes/one',null,false);
  await doc(b,prefix+'/members/'+a.id,{nickname:'forged'},false);
  await storage(a,prefix+'/notes/one/image',true);
  await storage(b,prefix+'/notes/one/image',false,false);
  await storage(a,prefix+'/notes/one/bad',true,false,'text/html');
  await doc(b,prefix+'/members/'+b.id,{nickname:'B'});
  await doc(b,prefix+'/notes/one');
  await storage(b,prefix+'/notes/one/image',false);
  await doc(b,prefix+'/notes/one',{...note,body:'editado',editor:b.id});
  await doc(b,prefix+'/notes/one',{...note,editor:b.id,mediaPath:'spaces/other/secret'},false);
  const score={user_id:a.id,nickname:'A',game:'blocks-v1',score:100,updated_at:'now'};
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',score);
  await doc(b,prefix+'/scores/'+a.id+'_blocks-v1',{...score,user_id:b.id},false);
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',{...score,score:50},false);
  await doc(a,prefix+'/scores/'+a.id+'_blocks-v1',{...score,score:150});
  await realtime(a,prefix+'/members/'+a.id,true);
  await realtime(b,prefix+'/presence',undefined,false);
  await realtime(a,prefix+'/presence/'+a.id+'/device',{name:'A',since:1});
  await realtime(b,prefix+'/presence/'+a.id+'/device',null,false);
  await realtime(b,prefix+'/members/'+b.id,true);
  await realtime(b,prefix+'/presence');
  console.log('PASS: private progress, stale revisions, mural invitations, images, presence and impersonation.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
