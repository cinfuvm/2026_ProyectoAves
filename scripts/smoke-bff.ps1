<#
.SYNOPSIS
  Prueba de humo del BFF: salud, CORS, autenticación y el proxy de /images.

.DESCRIPTION
  Comprueba que el BFF responde en el puerto indicado y que el proxy hacia el
  backend funciona. Si el backend no está alcanzable, las rutas deben responder
  502 (y NO quedarse colgadas).

  Cubre además las 3 formas de /images que usa la app móvil: listado público
  (GET con query), subida multipart (POST) y reporte (PUT con ?id=), porque
  el cuerpo binario es lo más fácil de romper en un proxy.

  Usa curl.exe para capturar cuerpo y estado de las respuestas de error.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\smoke-bff.ps1
  powershell -ExecutionPolicy Bypass -File scripts\smoke-bff.ps1 -BaseUrl http://192.168.1.2:4000
#>
[CmdletBinding()]
param(
  [string]$BaseUrl = 'http://127.0.0.1:4000',
  [string]$Token = 'token-de-prueba'
)

$ErrorActionPreference = 'Stop'
$fallos = 0
$cuerpoTmp = Join-Path $env:TEMP 'smoke_bff_body.txt'

# Devuelve @{ Codigo; Cuerpo } usando curl.exe, que sí captura el cuerpo de
# respuestas 4xx/5xx (Invoke-WebRequest deja el stream vacío en PS 5.1).
function Llamar($Metodo, $Ruta, $Cuerpo, $Cabeceras) {
  $args = @('-s', '-o', $script:cuerpoTmp, '-w', '%{http_code}',
            '-X', $Metodo, "$script:BaseUrl$Ruta", '--max-time', '20')
  foreach ($h in $Cabeceras) { $args += @('-H', $h) }
  if ($null -ne $Cuerpo) {
    $args += @('-H', 'Content-Type: application/json', '-d', $Cuerpo)
  }
  $codigo = & curl.exe @args 2>$null
  $texto = if (Test-Path $script:cuerpoTmp) { Get-Content $script:cuerpoTmp -Raw -Encoding UTF8 } else { '' }
  @{ Codigo = [int]$codigo; Cuerpo = if ($texto) { $texto.Trim() } else { '' } }
}

function Probar($Metodo, $Ruta, $Cuerpo, $Esperados, [string[]]$Cabeceras = @()) {
  $t = [Diagnostics.Stopwatch]::StartNew()
  $r = Llamar $Metodo $Ruta $Cuerpo $Cabeceras
  $ok = $Esperados -contains $r.Codigo
  if (-not $ok) { $script:fallos++ }
  $corto = if ($r.Cuerpo.Length -gt 90) { $r.Cuerpo.Substring(0, 90) + [char]0x2026 } else { $r.Cuerpo }
  Write-Host ("  [{0,-6} {1,-22}] {2,-4} {3}  ({4} ms)" -f $Metodo, $Ruta, $r.Codigo, $corto, $t.ElapsedMilliseconds) `
    -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
}

Write-Host ""
Write-Host "== BFF en $BaseUrl ==" -ForegroundColor Cyan

Write-Host "`n- Salud"
Probar 'GET' '/' $null @(200)

Write-Host "`n- CORS (preflight, como haria Flutter Web)"
$r = Llamar 'OPTIONS' '/api/user/login' $null @('Origin: http://localhost:53421')
$allow = (& curl.exe -s -D - -o NUL -X OPTIONS "$BaseUrl/api/user/login" --max-time 10 |
  Select-String -Pattern '^access-control-allow-origin:\s*(.+)$').Matches.Groups[1].Value.Trim()
if ($r.Codigo -eq 204 -and $allow -eq '*') {
  Write-Host "  [OPTIONS /api/user/login     ] 204  allow-origin: $allow" -ForegroundColor Green
} else {
  Write-Host "  [OPTIONS /api/user/login     ] FALLO codigo=$($r.Codigo) allow-origin='$allow'" -ForegroundColor Red
  $fallos++
}

Write-Host "`n- Autenticacion (las 4 rutas que usa la app)"
Probar 'POST'   '/api/user/signin' '{"email":"smoke@aves.cl","nickname":"smoke","password":"secret123","confirm_password":"secret123"}' @(200,201,409,422,502)
Probar 'POST'   '/api/user/login'  '{"email":"smoke@aves.cl","password":"secret123"}'                                   @(200,401,422,502)
Probar 'GET'    '/api/user/me'     $null                                                                                  @(200,401,403,502) @("Authorization: Bearer $Token")
Probar 'DELETE' '/api/user/logout' $null                                                                                  @(200,204,401,502) @("Authorization: Bearer $Token")
Probar 'GET'    '/api/user/me'     $null                                                                                  @(200,401,403,502)

Write-Host "`n- Validacion de metodos (deben dar 405 con mensaje)"
Probar 'POST'   '/api/user/me'     '{}'  @(405)
Probar 'GET'    '/api/user/login'  $null @(405)
Probar 'DELETE' '/images'          $null @(405)

Write-Host "`n- /images (el cuerpo binario es lo mas fragil del proxy)"
Probar 'GET'  '/images?categoria=ave&pagina=0&por_pagina=2' $null @(200,502)
Probar 'PUT'  '/images?id=foto-1' '{"motivo":"inapropiado"}' @(200,201,401,403,502) @("Authorization: Bearer $Token")

# Subida multipart: se sube un archivo real para que el boundary viaje entero.
$tmpArchivo = Join-Path $env:TEMP 'smoke_bff_foto.bin'
Set-Content -Path $tmpArchivo -Value ('aves-' * 200) -Encoding Ascii
$t = [Diagnostics.Stopwatch]::StartNew()
$codigo = & curl.exe -s -o $script:cuerpoTmp -w '%{http_code}' --max-time 20 `
  -X POST "$BaseUrl/images" -H "Authorization: Bearer $Token" `
  -F "archivo=@$tmpArchivo;type=image/jpeg" -F 'categoria=ave' 2>$null
$texto = Get-Content $script:cuerpoTmp -Raw -Encoding UTF8
$okSubida = [int]$codigo -in 200, 201, 401, 403, 502
if (-not $okSubida) { $fallos++ }
Write-Host ("  [{0,-6} {1,-22}] {2,-4} {3}  ({4} ms)" -f 'POST', '/images (multipart)', $codigo, `
  $(if ($texto) { $texto.Trim().Substring(0, [Math]::Min(70, $texto.Trim().Length)) } else { '' }), $t.ElapsedMilliseconds) `
  -ForegroundColor $(if ($okSubida) { 'Green' } else { 'Red' })
Remove-Item $tmpArchivo -Force -ErrorAction SilentlyContinue

Write-Host "`n- Forma de la sesion (la app asume {data:{token,user:{...}}})"
$r = Llamar 'POST' '/api/user/login' '{"email":"smoke@aves.cl","password":"secret123"}' @()
if ($r.Codigo -eq 200) {
  try {
    $json = $r.Cuerpo | ConvertFrom-Json
    $formaOk = $null -ne $json.data.token -and $null -ne $json.data.user.email
  } catch { $formaOk = $false }
  if ($formaOk) {
    Write-Host "  [forma login               ] OK   token + user.email presentes" -ForegroundColor Green
  } else {
    Write-Host "  [forma login               ] FALLO $($r.Cuerpo)" -ForegroundColor Red
    $fallos++
  }
} else {
  Write-Host "  [forma login               ] salteado (HTTP $($r.Codigo))" -ForegroundColor Yellow
}

if (Test-Path $cuerpoTmp) { Remove-Item $cuerpoTmp -Force }

Write-Host ""
if ($fallos -eq 0) {
  Write-Host "OK: todas las comprobaciones pasaron." -ForegroundColor Green
} else {
  Write-Host "FALLARON $fallos comprobacion(es)." -ForegroundColor Red
  exit 1
}
