<#
.SYNOPSIS
  Arranca el BFF (Dart Frog) en 0.0.0.0:4000.

.DESCRIPTION
  Usa `dart_frog dev` (con hot reload) y publica en todas las interfaces para
  que el emulador (10.0.2.2) y un celular en la misma red puedan llegar.

  BACKEND_URL por defecto: http://127.0.0.1:4001 (el backend Phoenix de dev).

.EXAMPLE
  pwsh -File scripts/bff.ps1
  pwsh -File scripts/bff.ps1 -BackendUrl http://127.0.0.1:4001
#>
[CmdletBinding()]
param(
  [string]$BackendUrl = 'http://127.0.0.1:4001',
  [string]$Host_ = '0.0.0.0',
  [int]$Puerto = 4000
)

$ErrorActionPreference = 'Stop'
$bff = Join-Path (Split-Path $PSScriptRoot -Parent) 'bff'

$dartFrog = Get-Command dart_frog -ErrorAction SilentlyContinue
if (-not $dartFrog) {
  $local = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin\dart_frog.bat'
  if (-not (Test-Path $local)) {
    Write-Error "No se encontró el CLI de Dart Frog. Instálalo con: dart pub global activate dart_frog_cli"
  }
  $dartFrogCmd = $local
} else {
  $dartFrogCmd = $dartFrog.Source
}

$env:BACKEND_URL = $BackendUrl
Write-Host "BFF -> $Host_`:$Puerto | BACKEND_URL=$BackendUrl"
Set-Location $bff
& $dartFrogCmd dev --hostname $Host_ --port $Puerto
