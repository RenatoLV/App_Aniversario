// Uses the existing Firebase CLI login; never prints credentials.
const auth = require(process.env.APPDATA + '/npm/node_modules/firebase-tools/lib/auth');
async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw Error('Run firebase login first');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  if (process.argv.includes('--storage-permissions')) {
    const base = 'https://cloudresourcemanager.googleapis.com/v1/projects/cumplemes:';
    const headers = {Authorization:'Bearer '+token.access_token, 'Content-Type':'application/json'};
    const response = await fetch(base+'getIamPolicy', {method:'POST',headers,body:'{}'});
    const policy = await response.json();
    if (!response.ok) throw Error('Cannot inspect Storage/Firestore permission: '+response.status);
    const role = 'roles/firebaserules.firestoreServiceAgent';
    const member = 'serviceAccount:service-273979503185@firebase-rules.iam.gserviceaccount.com';
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
