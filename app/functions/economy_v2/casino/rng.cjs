'use strict';
const crypto=require('node:crypto');
const {canonical}=require('../common.cjs');
const contextDomain='anivermaru/lucky777/intent/v1',streamDomain='anivermaru/lucky777/stream/v1';
function createRandom(key,context) {
  if(!Buffer.isBuffer(key)||key.length<32)throw Error('private key must have at least 256 bits');
  const root=crypto.createHmac('sha256',key).update(canonical({...context,domain:contextDomain})).digest();
  let block=Buffer.alloc(0),position=0,counter=0;
  function word() {
    if(position>=block.length){
      if(counter>0xffffffff)throw Error('random stream exhausted');
      const index=Buffer.alloc(4);index.writeUInt32BE(counter++);
      block=crypto.createHmac('sha256',root).update(streamDomain).update(Buffer.from([0])).update(index).digest();position=0;
    }
    const value=block.readUInt32BE(position);position+=4;return value;
  }
  return {nextInt:max=>uniform(word,max)};
}
function uniform(word,max) {
  if(!Number.isInteger(max)||max<1||max>0x100000000)throw Error('invalid random range');
  const limit=0x100000000-(0x100000000%max);
  let n;do{n=word();if(!Number.isInteger(n)||n<0||n>=0x100000000)throw Error('invalid random word');}while(n>=limit);
  return n%max;
}
module.exports={createRandom,uniform};
