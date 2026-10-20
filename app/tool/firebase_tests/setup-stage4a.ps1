$ErrorActionPreference = 'Stop'
# Portable, pinned runtimes. No machine/user environment variables are changed.
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$target = Join-Path $repo '.tools/lucky-stage4a'
New-Item -ItemType Directory -Force $target | Out-Null
$packages = @(
  @{Name='jdk'; File='OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip'; Url='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip'; Hash='f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e'},
  @{Name='node'; File='node-v22.23.3-win-x64.zip'; Url='https://nodejs.org/dist/v22.23.3/node-v22.23.3-win-x64.zip'; Hash='2b0ff57b049cda1bbcea2240eec20467018713c1efe1f7360c2681859b90ed71'}
)
foreach ($package in $packages) {
  $archive = Join-Path $target $package.File
  if (!(Test-Path -LiteralPath $archive)) {
    & curl.exe --fail --location --silent --show-error --output $archive $package.Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $($package.Name)" }
  }
  if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $package.Hash) {
    throw "Checksum mismatch: $archive. Do not execute this archive."
  }
  $folder = Join-Path $target $package.Name
  if (!(Test-Path -LiteralPath $folder)) { Expand-Archive -LiteralPath $archive -DestinationPath $folder }
}
Write-Output "Pinned runtimes ready in $target (gitignored). Run run-stage4a.ps1."
