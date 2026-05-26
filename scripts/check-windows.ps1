#Requires -Version 5.1
param(
  [string]$HostName = "127.0.0.1",
  [int]$ApiPort = 2233,
  [int]$ProxyPort = 2234
)
$ErrorActionPreference = "Stop"

Write-Host "== native version =="
Invoke-RestMethod "http://${HostName}:$ApiPort/meme/version"

Write-Host "== native keys =="
$native = Invoke-RestMethod "http://${HostName}:$ApiPort/meme/keys"
$native.Count

Write-Host "== compat keys =="
$compat = Invoke-RestMethod "http://${HostName}:$ProxyPort/memes/keys"
$compat.Count

Write-Host "== compat petpet info =="
$info = Invoke-RestMethod "http://${HostName}:$ProxyPort/memes/petpet/info"
$info.key
$info.params_type
