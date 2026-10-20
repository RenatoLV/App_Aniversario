'use strict';
// Prepared only: not imported by production index or bound to any deployed Function.
const {defineSecret}=require('firebase-functions/params');
const {decodeKeyring}=require('./keys.cjs');
const casinoKeyring=defineSecret('LUCKY777_KEYRING_JSON');
function runtimeKeys(epoch){return decodeKeyring(casinoKeyring.value(),epoch);}
module.exports={casinoKeyring,runtimeKeys};
