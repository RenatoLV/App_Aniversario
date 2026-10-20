param([ValidateSet('baseline','v2','backend','casino','demo','node','serve','seed','client')][string]$Suite = 'v2', [string]$BindHost = '127.0.0.1')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runtime = Join-Path $repo '.tools/lucky-stage4a'
$javaHome = Join-Path $runtime 'jdk/jdk-21.0.12.1+1'
$nodeHome = Join-Path $runtime 'node/node-v22.23.3-win-x64'
if (!(Test-Path "$javaHome/bin/java.exe") -or !(Test-Path "$nodeHome/node.exe")) { throw 'Run setup-stage4a.ps1 first.' }
$oldPath = $env:PATH; $oldJava = $env:JAVA_HOME
$oldProject = $env:GCLOUD_PROJECT; $oldGoogleProject = $env:GOOGLE_CLOUD_PROJECT
$oldCredentials = $env:GOOGLE_APPLICATION_CREDENTIALS; $oldConfig = $env:FIREBASE_CONFIG
try {
  $env:PATH = "$nodeHome;$javaHome/bin;$oldPath"; $env:JAVA_HOME = $javaHome
  $env:GCLOUD_PROJECT = 'demo-lucky-readiness'; $env:GOOGLE_CLOUD_PROJECT = 'demo-lucky-readiness'
  Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS -ErrorAction SilentlyContinue
  Remove-Item Env:FIREBASE_CONFIG -ErrorAction SilentlyContinue
  & node --version; & java -version
  Push-Location (Join-Path $repo 'app')
  try {
    if ($Suite -eq 'seed') {
      $previousAuth=$env:FIREBASE_AUTH_EMULATOR_HOST; $previousFirestore=$env:FIRESTORE_EMULATOR_HOST
      try {
        $env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:19099'; $env:FIRESTORE_EMULATOR_HOST='127.0.0.1:18186'
        & node 'tool/lucky_casino_demo.cjs' --seed-only
      } finally { $env:FIREBASE_AUTH_EMULATOR_HOST=$previousAuth; $env:FIRESTORE_EMULATOR_HOST=$previousFirestore }
    } elseif ($Suite -eq 'node') {
      & node --test 'functions/test/*.test.cjs'
    } else {
      if ((& firebase.cmd --version) -ne '15.28.2') { throw 'Use firebase-tools 15.28.2 for this recorded test configuration.' }
      # Firebase forbids rules outside the config root. Generate an ignored sandbox
      # with an exact copy; never rewrite the production config or rule file.
      $sandbox = Join-Path $repo 'app/build/lucky-stage4a'
      New-Item -ItemType Directory -Force $sandbox | Out-Null
      $template = if ($Suite -eq 'baseline') {'firebase.readiness.json'} else {'firebase.stage4a.json'}
      $rules = if ($Suite -eq 'baseline') {Join-Path $repo 'app/firestore.rules'} else {Join-Path $PSScriptRoot 'economy-v2.proposed.rules'}
      Copy-Item -LiteralPath (Join-Path $PSScriptRoot $template) -Destination (Join-Path $sandbox 'firebase.json')
      Copy-Item -LiteralPath $rules -Destination (Join-Path $sandbox 'firestore.rules')
      $config = Join-Path $sandbox 'firebase.json'
      if ($Suite -in @('backend','casino','demo','serve','client')) {
        $functionsSandbox = Join-Path $sandbox 'functions'
        New-Item -ItemType Directory -Force $functionsSandbox | Out-Null
        foreach ($module in @('service.cjs','http.cjs','common.cjs')) {
          Copy-Item -LiteralPath (Join-Path $repo "app/functions/economy_v2/$module") -Destination (Join-Path $functionsSandbox $module)
        }
        New-Item -ItemType Directory -Force (Join-Path $functionsSandbox 'casino') | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $repo 'app/functions/economy_v2/casino') -File | Copy-Item -Destination (Join-Path $functionsSandbox 'casino')
        $secretFile = Join-Path $functionsSandbox 'casino-keys.local.json'
        if (!(Test-Path -LiteralPath $secretFile)) {
          $keyring = @{}
          foreach ($epoch in @('sandbox-epoch-1','sandbox-epoch-2')) {
            $bytes = New-Object byte[] 32
            $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
            try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
            $keyring[$epoch] = [Convert]::ToHexString($bytes).ToLowerInvariant()
          }
          $keyring | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath $secretFile
        }
        Copy-Item -LiteralPath (Join-Path $repo 'app/functions/economy_v2/emulator-entry.cjs') -Destination (Join-Path $functionsSandbox 'index.cjs')
        Copy-Item -LiteralPath (Join-Path $repo 'app/functions/package.json') -Destination (Join-Path $functionsSandbox 'package.json')
        $modules = Join-Path $functionsSandbox 'node_modules'
        if (!(Test-Path -LiteralPath $modules)) {
          New-Item -ItemType Junction -Path $modules -Target (Join-Path $repo 'app/functions/node_modules') | Out-Null
        }
        $settings = Get-Content -Raw -LiteralPath $config | ConvertFrom-Json
        $settings | Add-Member -NotePropertyName functions -NotePropertyValue @{source='functions';runtime='nodejs22'}
        $settings.emulators | Add-Member -NotePropertyName functions -NotePropertyValue @{host='127.0.0.1';port=15001}
        if ($BindHost -notin @('127.0.0.1','0.0.0.0')) { throw 'BindHost must be loopback or explicitly 0.0.0.0 for a private LAN device.' }
        foreach ($name in @('auth','firestore','functions')) { $settings.emulators.$name.host=$BindHost }
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -LiteralPath $config
      }
      $test = if ($Suite -eq 'baseline') {'lucky_readiness.test.cjs'} elseif ($Suite -eq 'backend') {'stage4b.test.cjs'} elseif ($Suite -eq 'casino') {'stage4c1.test.cjs'} else {'stage4a.test.cjs'}
      $testPath = (Join-Path $PSScriptRoot $test).Replace('\','/')
      $command = if ($Suite -eq 'baseline') {"node `"$testPath`""} else {"node --test `"$testPath`""}
      if ($Suite -eq 'demo') {
        $demoPath = (Join-Path $repo 'app/tool/lucky_casino_demo.cjs').Replace('\','/')
        $command = "node `"$demoPath`""
      }
      if ($Suite -eq 'client') {
        $clientPath=(Join-Path $PSScriptRoot 'run-client.ps1').Replace('\','/')
        $command="pwsh -NoProfile -File `"$clientPath`""
      }
      $only = if ($Suite -in @('backend','casino','demo','serve','client')) {'auth,firestore,functions'} else {'auth,firestore'}
      if ($Suite -eq 'serve') {
        Write-Host 'Persistent isolated demo. In another terminal run -Suite seed. Stop with Ctrl+C.'
        & firebase.cmd emulators:start --project demo-lucky-readiness --config $config --only $only
      } else {
        & firebase.cmd emulators:exec --project demo-lucky-readiness --config $config --only $only $command
      }
    }
    if ($LASTEXITCODE -ne 0) { throw "Suite $Suite failed with exit $LASTEXITCODE" }
  } finally { Pop-Location }
} finally {
  $env:PATH=$oldPath; $env:JAVA_HOME=$oldJava
  $env:GCLOUD_PROJECT=$oldProject; $env:GOOGLE_CLOUD_PROJECT=$oldGoogleProject
  $env:GOOGLE_APPLICATION_CREDENTIALS=$oldCredentials; $env:FIREBASE_CONFIG=$oldConfig
}
