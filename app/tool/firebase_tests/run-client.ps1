$ErrorActionPreference='Stop'
Push-Location ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))
try {
  & node tool/lucky_casino_demo.cjs --seed-only
  if($LASTEXITCODE -ne 0){throw 'Fixture failed'}
  & node tool/firebase_tests/client-fixture.cjs
  if($LASTEXITCODE -ne 0){throw 'Client fixture failed'}
  & C:/src/flutter/bin/flutter.bat test test/lucky_remote_emulator_test.dart --dart-define=LUCKY_REMOTE_EMULATOR=true
  if($LASTEXITCODE -ne 0){throw 'Flutter emulator client failed'}
} finally { Pop-Location }
