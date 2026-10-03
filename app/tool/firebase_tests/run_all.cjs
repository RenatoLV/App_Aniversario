'use strict';
const {spawnSync}=require('node:child_process');
for(const suite of ['rules.test.cjs','bomber.test.cjs']){
  const run=spawnSync(process.execPath,[require('node:path').join(__dirname,suite)],{stdio:'inherit',env:process.env});
  if(run.status!==0)process.exit(run.status||1);
}
