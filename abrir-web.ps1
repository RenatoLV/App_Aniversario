$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot 'app'
$flutterCommand = 'C:\src\flutter\bin\flutter.bat'
$pythonCommand = 'C:\Python314\python.exe'
$webPort = 7360
$webUrl = "http://127.0.0.1:$webPort/"

try {
    if (!(Test-Path -LiteralPath $flutterCommand) -or !(Test-Path -LiteralPath $pythonCommand)) {
        throw 'No se encontro Flutter o Python en las rutas configuradas.'
    }
    Set-Location -LiteralPath $appDirectory
    Write-Host 'Compilando Anivermaru para web...' -ForegroundColor Cyan
    & $flutterCommand build web --release
    if ($LASTEXITCODE -ne 0) { throw 'La compilacion fallo. Revisa los mensajes anteriores.' }

    $webDirectory = Join-Path $appDirectory 'build\web'
    $listener = Get-NetTCPConnection -LocalPort $webPort -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $serverProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener[0].OwningProcess)"
        if ($serverProcess.CommandLine -notlike '*http.server*' -or
            $serverProcess.CommandLine -notlike "*$webDirectory*") {
            throw "El puerto $webPort esta ocupado por otra aplicacion."
        }
    } else {
        Start-Process -FilePath $pythonCommand -ArgumentList @(
            '-m', 'http.server', "$webPort", '--bind', '127.0.0.1',
            '--directory', "`"$webDirectory`""
        ) -WorkingDirectory $webDirectory -WindowStyle Hidden
    }
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $webUrl -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 300 }
    }
    if (!$ready) { throw 'El servidor web no respondio.' }
    Start-Process $webUrl
    Write-Host "App lista en $webUrl" -ForegroundColor Green
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host 'Presiona Enter para cerrar'
    exit 1
}
