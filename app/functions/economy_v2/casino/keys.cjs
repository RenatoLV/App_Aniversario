'use strict';
// Runtime boundary shared by local synthetic keys and a future Secret Manager
// JSON parameter. No embedded/default economic key and no network access here.
function decodeKeyring(json,currentEpoch){
  const raw=JSON.parse(json);
  if(!raw||Array.isArray(raw)||typeof raw!=='object')throw Error('invalid keyring');
  const keyring=Object.create(null);
  for(const [epoch,hex] of Object.entries(raw)){
    if(!/^[a-zA-Z0-9._-]{1,64}$/.test(epoch)||['constructor','__proto__','prototype'].includes(epoch)
      ||typeof hex!=='string'||!/^[a-f0-9]{64}$/.test(hex))throw Error('invalid keyring entry');
    keyring[epoch]=Buffer.from(hex,'hex');
  }
  if(!Object.hasOwn(keyring,currentEpoch))throw Error('current epoch key missing');
  return {keyring:Object.freeze(keyring),currentEpoch};
}
module.exports={decodeKeyring};
