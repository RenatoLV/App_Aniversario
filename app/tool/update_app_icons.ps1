$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$appRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Join-Path $appRoot 'assets\anivermaru_logo.png'))
try {
    $targets = @{
        'web\favicon.png' = 64
        'web\icons\Icon-192.png' = 192
        'web\icons\Icon-512.png' = 512
        'web\icons\Icon-maskable-192.png' = 192
        'web\icons\Icon-maskable-512.png' = 512
        'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
        'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
        'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
        'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
        'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
    }
    foreach ($entry in $targets.GetEnumerator()) {
        $size = $entry.Value
        $bitmap = [System.Drawing.Bitmap]::new($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 115, 160, 246))
            $inset = if ($entry.Key.Contains('maskable')) { [int]($size * .1) } else { 0 }
            $graphics.DrawImage($source, $inset, $inset, $size - 2 * $inset, $size - 2 * $inset)
            $bitmap.Save((Join-Path $appRoot $entry.Key), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
} finally { $source.Dispose() }
