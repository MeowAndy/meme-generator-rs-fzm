#Requires -Version 5.1
param(
  [string]$InstallDir = "C:\meme-api",
  [string[]]$LibraryUrls = @("https://github.com/anyliew/meme-emoji/releases/download/v0.0.6%2Bbuild.43/meme-emoji-windows-x86_64.dll")
)
$ErrorActionPreference = "Stop"
$libDir = Join-Path $InstallDir "data\libraries"
New-Item -ItemType Directory -Force -Path $libDir | Out-Null

# Allow override by libraries.env, line example:
# MEME_LIBRARY_URLS="https://.../a.dll https://.../b.dll"
$envFile = Join-Path $InstallDir "libraries.env"
if (Test-Path $envFile) {
  $line = Get-Content $envFile | Where-Object { $_ -match '^MEME_LIBRARY_URLS=' } | Select-Object -First 1
  if ($line) {
    $value = $line -replace '^MEME_LIBRARY_URLS=', ''
    $value = $value.Trim().Trim('"')
    if ($value) {
      # If Linux .so default is present, map known meme-emoji linux asset to Windows dll.
      $value = $value -replace 'meme-emoji-linux-x86_64\.so', 'meme-emoji-windows-x86_64.dll'
      $LibraryUrls = $value -split '\s+'
    }
  }
}

foreach ($url in $LibraryUrls) {
  $name = [IO.Path]::GetFileName(($url -split '\?')[0])
  if (-not $name.EndsWith('.dll')) {
    Write-Warning "Skipping non-Windows library asset: $name"
    continue
  }
  $tmp = Join-Path $env:TEMP $name
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  if ((Get-Item $tmp).Length -le 0) { throw "Downloaded file is empty: $url" }
  Copy-Item -Force $tmp (Join-Path $libDir $name)
  Write-Host "Updated $(Join-Path $libDir $name)"
}

Write-Host "Libraries updated. Restart meme API to load new libraries."
