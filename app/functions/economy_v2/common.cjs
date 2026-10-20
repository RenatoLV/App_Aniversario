'use strict';
const crypto=require('node:crypto');
function normalize(value) {
  if(Array.isArray(value)) return value.map(normalize);
  if(value&&typeof value==='object') return Object.fromEntries(Object.keys(value).sort().map(k=>[k,normalize(value[k])]));
  return value;
}
const canonical=value=>JSON.stringify(normalize(value));
const digest=value=>crypto.createHash('sha256').update(canonical(value)).digest('hex');
class EconomicError extends Error {
  constructor(code,status=400){super(code);this.code=code;this.status=status;}
}
module.exports={canonical,digest,EconomicError};
