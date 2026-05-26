#Requires -Version 5.1
param(
  [string]$InstallDir = "C:\meme-api",
  [int]$ApiPort = 2233,
  [int]$ProxyPort = 2234,
  [string]$ProxyHost = "0.0.0.0",
  [string]$Backend = "http://127.0.0.1:2233",
  [string]$Fallback = "https://meme.pippi.top/pippi"
)
$ErrorActionPreference = "Stop"

$env:MEME_HOME = Join-Path $InstallDir "data"
$env:MEME_BACKEND = $Backend
$env:MEME_FALLBACK = $Fallback
$env:MEME_ENABLE_FALLBACK = "1"

$memeExe = Join-Path $InstallDir "bin\meme.exe"
$proxyPy = Join-Path $InstallDir "proxy\meme_compat_proxy.py"
if (-not (Test-Path $memeExe)) { throw "Missing $memeExe. Run install-windows.ps1 first." }
if (-not (Test-Path $proxyPy)) { throw "Missing $proxyPy. Run install-windows.ps1 first." }

$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { throw "Python not found" }

Write-Host "Starting meme API on 0.0.0.0:$ApiPort ..."
$api = Start-Process -FilePath $memeExe -ArgumentList @("server", "--host", "0.0.0.0", "--port", "$ApiPort") -WorkingDirectory $InstallDir -PassThru
Start-Sleep -Seconds 2
Write-Host "Starting compat proxy on ${ProxyHost}:$ProxyPort ..."
$proxy = Start-Process -FilePath $py.Source -ArgumentList @($proxyPy, "--host", $ProxyHost, "--port", "$ProxyPort") -WorkingDirectory $InstallDir -PassThru

Write-Host ""
Write-Host "Started. Press Ctrl+C to stop child processes."
Write-Host "Native API: http://127.0.0.1:$ApiPort"
Write-Host "Compat API: http://127.0.0.1:$ProxyPort"
Write-Host ""
try {
  while ($true) {
    if ($api.HasExited) { throw "meme API exited with code $($api.ExitCode)" }
    if ($proxy.HasExited) { throw "compat proxy exited with code $($proxy.ExitCode)" }
    Start-Sleep -Seconds 3
  }
} finally {
  foreach ($p in @($api, $proxy)) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  }
}
