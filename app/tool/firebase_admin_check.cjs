// Uses the existing Firebase CLI login; never prints credentials.
const auth = require(process.env.APPDATA + '/npm/node_modules/firebase-tools/lib/auth');
async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw Error('Run firebase login first');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  if (process.argv.includes('--migrate-leaderboard') || process.argv.includes('--audit-leaderboard')) {
    const base = 'https://firestore.googleapis.com/v1/projects/cumplemes/databases/(default)/documents';
    const headers = {Authorization:'Bearer '+token.access_token,'Content-Type':'application/json'};
    async function api(url, body) {
      const response = await fetch(url,{headers,signal:AbortSignal.timeout(20000),
        ...(body ? {method:'POST',body:JSON.stringify(body)} : {})});
      if (response.status === 404) return null;
      const data = await response.json();
      if (!response.ok) throw Error('Leaderboard request '+response.status+' '+(data.error?.message || 'failed'));
      return data;
    }
    const legacy = await api(base+':runQuery',{structuredQuery:{from:[{collectionId:'scores',allDescendants:true}]}});
    const best = new Map();
    for (const row of legacy) {
      const f = row.document?.fields;
      if (!f) continue;
      const uid=f.user_id?.stringValue, game=f.game?.stringValue, score=Number(f.score?.integerValue);
      if (!uid || !['blocks-v1','wordlady','candy-churu-cat','ascenso-maruzon'].includes(game)
        || !Number.isSafeInteger(score) || score <= 0) continue;
      const id=uid+'_'+game;
      if (!best.has(id) || best.get(id).score < score)
        best.set(id,{uid,game,score,nickname:f.nickname?.stringValue || 'Jugador'});
    }
    console.log('Historical leaderboard',JSON.stringify({players:new Set([...best.values()].map(x=>x.uid)).size,records:best.size}));
    if (process.argv.includes('--migrate-leaderboard')) {
      for (const [id,record] of best) {
        for (let attempt=0;attempt<3;attempt++) {
          const current=await api(base+'/game_scores/'+encodeURIComponent(id));
          const profile=await api(base+'/players/'+encodeURIComponent(record.uid)+'?mask.fieldPaths=nickname');
          const nickname=profile?.fields?.nickname?.stringValue || record.nickname;
          const score=Math.max(record.score,Number(current?.fields?.score?.integerValue || 0));
          if (current?.fields?.score?.integerValue===String(score) && current?.fields?.nickname?.stringValue===nickname) break;
          const fields={user_id:{stringValue:record.uid},nickname:{stringValue:nickname},
            game:{stringValue:record.game},score:{integerValue:String(score)},updated_at:{timestampValue:new Date().toISOString()}};
          try {
            await api(base+':commit',{writes:[{update:{name:base.slice('https://firestore.googleapis.com/v1/'.length)+'/game_scores/'+id,fields},
              currentDocument:current?{updateTime:current.updateTime}:{exists:false}}]});
            break;
          } catch (error) {if (attempt===2) throw error;}
        }
      }
    }
    const result=await api(base+'/game_scores?pageSize=100');
    console.log('Shared leaderboard',JSON.stringify((result?.documents || []).map(d=>({
      nickname:d.fields.nickname.stringValue,game:d.fields.game.stringValue,score:Number(d.fields.score.integerValue)}))));
    return;
  }
  if (process.argv.includes('--storage-permissions')) {
    const base = 'https://cloudresourcemanager.googleapis.com/v1/projects/cumplemes:';
    const headers = {Authorization:'Bearer '+token.access_token, 'Content-Type':'application/json'};
    const response = await fetch(base+'getIamPolicy', {method:'POST',headers,body:'{}'});
    const policy = await response.json();
    if (!response.ok) throw Error('Cannot inspect Storage/Firestore permission: '+response.status);
    const role = 'roles/firebaserules.firestoreServiceAgent';
    const member = 'serviceAccount:service-273979503185@gcp-sa-firebasestorage.iam.gserviceaccount.com';
    let binding = (policy.bindings || []).find(b => b.role === role && !b.condition);
    if (!binding?.members?.includes(member)) {
      if (!binding) { binding = {role,members:[]}; (policy.bindings ||= []).push(binding); }
      binding.members.push(member);
      const result = await fetch(base+'setIamPolicy', {method:'POST',headers,body:JSON.stringify({policy})});
      if (!result.ok) throw Error('Cannot enable Storage/Firestore permission: '+result.status);
      console.log('Storage/Firestore service permission enabled');
    } else console.log('Storage/Firestore service permission already enabled');
    return;
  }
  if (process.argv.includes('--diagnose-notes')) {
    const headers = {Authorization:'Bearer '+token.access_token, 'Content-Type':'application/json'};
    async function api(url, body) {
      const response = await fetch(url, {headers, signal:AbortSignal.timeout(20000),
        ...(body ? {method:'POST',body:JSON.stringify(body)} : {})});
      const data = await response.json();
      if (!response.ok) throw Error('Firebase diagnostic '+response.status+' '+(data.error?.message || url));
      return data;
    }
    const project = 'https://cloudresourcemanager.googleapis.com/v1/projects/cumplemes';
    const policy = await api(project+':getIamPolicy', {});
    console.log('cross-service IAM', JSON.stringify((policy.bindings || [])
      .filter(b => /firebaserules|firebasestorage/.test(b.role))
      .map(b => ({role:b.role, members:b.members.filter(m => /gserviceaccount.com$/.test(m)), conditional:!!b.condition}))));
    const base = 'https://firebaserules.googleapis.com/v1/';
    const releases = await api(base+'projects/cumplemes/releases');
    const fs = require('node:fs');
    const path = require('node:path');
    for (const release of releases.releases || []) {
      if (!/firebase.storage|cloud.firestore/.test(release.name)) continue;
      const rules = await api(base+release.rulesetName);
      for (const file of rules.source?.files || []) {
        const local = path.join(__dirname,'..',file.name);
        console.log('deployed rules',JSON.stringify({release:release.name,file:file.name,
          matchesLocal:fs.existsSync(local) && fs.readFileSync(local,'utf8').replace(/\r/g,'')===file.content.replace(/\r/g,''),
          source:process.argv.includes('--show-rules') ? file.content : undefined}));
      }
    }
    const documents = 'https://firestore.googleapis.com/v1/projects/cumplemes/databases/(default)/documents';
    const email = process.argv.find(a=>a.startsWith('--email='))?.slice(8);
    if (!email) return;
    const rows = await api(documents+':runQuery', {structuredQuery:{
      from:[{collectionId:'players'}],
      select:{fields:[{fieldPath:'spaceId'}]},
      where:{fieldFilter:{field:{fieldPath:'email'},op:'EQUAL',value:{stringValue:email}}},limit:1}});
    const player = rows.find(row=>row.document)?.document;
    if (!player) {console.log('Player profile not found'); return;}
    const uid = player.name.split('/').pop();
    const space = player.fields?.spaceId?.stringValue;
    const member = await api(documents+'/spaces/'+space+'/members/'+uid);
    const notes = await api(documents+'/spaces/'+space+'/notes?pageSize=100&mask.fieldPaths=mediaPath&mask.fieldPaths=mediaKind');
    const objects = await api('https://storage.googleapis.com/storage/v1/b/cumplemes.firebasestorage.app/o?prefix='+encodeURIComponent('spaces/'+space+'/notes/')+'&maxResults=100&fields=items(name,size,contentType),nextPageToken');
    console.log('mural diagnostic',JSON.stringify({membershipExists:!!member.name,
      notes:(notes.documents || []).map(n=>({id:n.name.split('/').pop(),mediaKind:n.fields?.mediaKind?.stringValue,hasMedia:!!n.fields?.mediaPath?.stringValue})),
      storedObjects:(objects.items || []).map(o=>({size:o.size,contentType:o.contentType})),
      hasMoreObjects:!!objects.nextPageToken}));
    return;
  }
  for (const [name, url] of Object.entries({
    auth: 'https://identitytoolkit.googleapis.com/admin/v2/projects/cumplemes/config',
    providers: 'https://identitytoolkit.googleapis.com/admin/v2/projects/cumplemes/defaultSupportedIdpConfigs',
    firestore: 'https://firestore.googleapis.com/v1/projects/cumplemes/databases',
    storage: 'https://storage.googleapis.com/storage/v1/b/cumplemes.firebasestorage.app',
    rules: 'https://firebaserules.googleapis.com/v1/projects/cumplemes/releases',
  })) {
    const response = await fetch(url, {headers: {Authorization: 'Bearer ' + token.access_token}});
    const body = await response.json();
    if (name === 'providers') {
      console.log(name, response.status, JSON.stringify((body.defaultSupportedIdpConfigs || []).map(p => ({name:p.name, enabled:p.enabled}))));
    } else if (name === 'auth') {
      console.log(name, response.status, JSON.stringify({authorizedDomains:body.authorizedDomains, emailEnabled:body.signIn?.email?.enabled, error:body.error?.message}));
    } else {
      console.log(name, response.status, JSON.stringify(name === 'storage' ? {name:body.name,location:body.location,error:body.error?.message} : body));
    }
  }
  if (process.argv.includes('--local-domain')) {
    const url = 'https://identitytoolkit.googleapis.com/admin/v2/projects/cumplemes/config';
    const headers = {Authorization:'Bearer '+token.access_token, 'Content-Type':'application/json'};
    const config = await (await fetch(url, {headers})).json();
    const domains = [...new Set([...(config.authorizedDomains || []), '127.0.0.1'])];
    const result = await fetch(url+'?updateMask=authorizedDomains', {method:'PATCH', headers, body:JSON.stringify({authorizedDomains:domains})});
    console.log('authorize-localhost', result.status);
  }
}
main().catch(e => {console.error(e.message); process.exitCode=1;});
