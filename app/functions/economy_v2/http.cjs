'use strict';
const {createEconomyService,EconomicError,mutating}=require('./service.cjs');
// HTTP Bearer matches the existing cardTrades architecture. Not exported by the
// production entrypoint. App Check required unless explicitly bypassed in demo.
function isolatedDemo(env=process.env) {
  return env.FUNCTIONS_EMULATOR==='true' && env.GCLOUD_PROJECT==='demo-lucky-readiness'
    && ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'].every(k=>/^127\.0\.0\.1:\d+$/.test(env[k]||''));
}
function privateDemoOrigin(origin) {
  return /^http:\/\/(localhost|127\.0\.0\.1|10\.(\d{1,3}\.){2}\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(:\d+)?$/.test(origin);
}
function createEconomyHandler({db,auth,appCheck,syntheticEnabled=false,requireAppCheck=true,testFaults=false,now=()=>Date.now(),casinoOptions=null}) {
  const demo=isolatedDemo();
  syntheticEnabled=syntheticEnabled&&demo;
  testFaults=testFaults&&demo;
  requireAppCheck=requireAppCheck||!demo;
  const service=createEconomyService({db,syntheticEnabled,now,casinoOptions:demo?casinoOptions:null});
  async function rateLimit(uid) {
    const minute=Math.floor(now()/60000),r=service.ref(uid,'requestLimits',String(minute));
    await db.runTransaction(async tx=>{
      const old=await tx.get(r),count=old.exists?old.data().count:0;
      if(count>=120) throw new EconomicError('rate-limited',429);
      tx.set(r,{count:count+1,expiresAt:new Date((minute+2)*60000)});
    });
  }
  return async(req,res)=>{
    let operationId;
    try {
      // Emulator infrastructure may answer OPTIONS permissively before this
      // function. Reject disallowed browser origins on the actual POST as well.
      const origin=req.get('Origin');
      if(demo&&origin&&!privateDemoOrigin(origin))throw new EconomicError('invalid-demo-origin',403);
      if(req.method!=='POST') throw new EconomicError('method-not-allowed',405);
      if(!req.is('application/json')) throw new EconomicError('json-required',415);
      if((req.rawBody?.length||Buffer.byteLength(JSON.stringify(req.body||{})))>8192) throw new EconomicError('request-too-large',413);
      const bearer=(req.get('Authorization')||'').match(/^Bearer ([^\s]+)$/);
      if(!bearer) throw new EconomicError('unauthenticated',401);
      let claims;
      try {claims=await auth.verifyIdToken(bearer[1],true);} catch {throw new EconomicError('invalid-auth-token',401);}
      if(requireAppCheck) {
        try {
          const token=req.get('X-Firebase-AppCheck');
          if(!token) throw Error('missing');
          await appCheck.verifyToken(token);
        } catch {throw new EconomicError('invalid-app-check',403);}
      }
      await rateLimit(claims.uid);
      const input=req.body;operationId=input?.operationId;
      // Fault injection is private server state, only wired in the demo entry.
      const hooks={};
      if(testFaults&&mutating.has(input?.action)&&/^[a-f0-9]{32}$/.test(operationId||'')) {
        const faultRef=db.doc(`economy_v2_testControls/${claims.uid}/faults/${operationId}`);
        const fault=await db.runTransaction(async tx=>{
          const snap=await tx.get(faultRef);
          if(!snap.exists||snap.data().used) return null;
          tx.update(faultRef,{used:true});return snap.data().mode;
        });
        if(fault==='beforeCommit') hooks.beforeCommit=()=>{throw Error('test storage fault');};
        if(fault==='afterCommit') hooks.afterCommit=()=>{throw Error('test response lost');};
        if(fault==='delayedResponse') hooks.afterCommit=()=>new Promise(resolve=>setTimeout(resolve,2000));
        if(fault==='retryTransaction') {
          let attempts=0,first=null;
          hooks.beforeCommit=({round})=>{
            const fingerprint=JSON.stringify(round);
            if(!attempts++){first=fingerprint;const retry=Error('test aborted transaction');retry.code=10;throw retry;}
            if(first!==fingerprint)throw Error('non-deterministic transaction retry');
          };
          hooks.afterCommit=()=>faultRef.set({attempts},{merge:true});
        }
      }
      const result=await service.run(claims.uid,claims,input,hooks);
      res.status(200).json(result);
    } catch(error) {
      if(error instanceof EconomicError) return res.status(error.status).json({error:{code:error.code}});
      // A transport/storage failure is NOT a terminal financial denial. Always
      // recover/retry the same request; never claim that the charge did not occur.
      res.status(503).json({error:{code:'confirmation-unknown',...(typeof operationId==='string'&&/^[a-f0-9]{32}$/.test(operationId)?{operationId}:{})}});
    }
  };
}
module.exports={createEconomyHandler,isolatedDemo,privateDemoOrigin};
