#Requires -Version 5.1
<#
Install meme-generator-rs-fzm on Windows.
Run in an elevated PowerShell when binding firewall rules or installing NSSM.

Default install directory: C:\meme-api
Native API: 2233
meme-plugin compatible proxy: 2234
#>
param(
  [string]$InstallDir = "C:\meme-api",
  [string]$MemeVersion = "0.2.3",
  [int]$ApiPort = 2233,
  [int]$ProxyPort = 2234,
  [string]$ProxyHost = "0.0.0.0",
  [switch]$NoFirewall
)

$ErrorActionPreference = "Stop"

function Download-File($Url, $OutFile) {
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Ensure-PythonRequests {
  $py = Get-Command py -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
  if (-not $py) { throw "Python not found. Install Python 3 first: https://www.python.org/downloads/windows/" }
  & $py.Source -m pip install --upgrade requests
  return $py.Source
}

New-Item -ItemType Directory -Force -Path $InstallDir, "$InstallDir\bin", "$InstallDir\data", "$InstallDir\data\libraries", "$InstallDir\proxy", "$InstallDir\logs" | Out-Null

$zipUrl = "https://github.com/MemeCrafters/meme-generator-rs/releases/download/v$MemeVersion/meme-generator-cli-windows-x86_64.zip"
$tmp = Join-Path $env:TEMP "meme-generator-rs-$MemeVersion-win.zip"
$extract = Join-Path $env:TEMP "meme-generator-rs-$MemeVersion-win"
Remove-Item -Recurse -Force $extract -ErrorAction SilentlyContinue
Download-File $zipUrl $tmp
Expand-Archive -Force $tmp $extract
$memeExe = Get-ChildItem -Path $extract -Recurse -Filter "meme.exe" | Select-Object -First 1
if (-not $memeExe) { throw "meme.exe not found in release zip" }
Copy-Item -Force $memeExe.FullName "$InstallDir\bin\meme.exe"

Copy-Item -Force "$PSScriptRoot\..\proxy\meme_compat_proxy.py" "$InstallDir\proxy\meme_compat_proxy.py"
Copy-Item -Force "$PSScriptRoot\..\config\libraries.env" "$InstallDir\libraries.env"
Copy-Item -Force "$PSScriptRoot\..\scripts\start-windows.ps1" "$InstallDir\start-windows.ps1"
Copy-Item -Force "$PSScriptRoot\..\scripts\update-libraries-windows.ps1" "$InstallDir\update-libraries-windows.ps1"
Copy-Item -Force "$PSScriptRoot\..\scripts\check-windows.ps1" "$InstallDir\check-windows.ps1"

$python = Ensure-PythonRequests

& powershell -ExecutionPolicy Bypass -File "$InstallDir\update-libraries-windows.ps1" -InstallDir $InstallDir

if (-not $NoFirewall) {
  try {
    New-NetFirewallRule -DisplayName "meme-generator-rs API $ApiPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $ApiPort -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "meme-generator-rs compat proxy $ProxyPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $ProxyPort -ErrorAction SilentlyContinue | Out-Null
  } catch {
    Write-Warning "Firewall rule creation failed. Run PowerShell as Administrator or open ports $ApiPort,$ProxyPort manually. $_"
  }
}

Write-Host ""
Write-Host "Installed to $InstallDir"
Write-Host "Start both services in foreground:"
Write-Host "  powershell -ExecutionPolicy Bypass -File $InstallDir\start-windows.ps1"
Write-Host ""
Write-Host "Native API: http://SERVER_IP:$ApiPort"
Write-Host "meme-plugin compatible API: http://SERVER_IP:$ProxyPort"
