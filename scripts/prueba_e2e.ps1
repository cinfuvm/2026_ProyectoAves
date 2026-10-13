<#
.SYNOPSIS
  Flujo end-to-end de autenticación a través del BFF, en 9 pasos.

.DESCRIPTION
  Replica llamada a llamada lo que hace la app: signin, login, /me con y sin
  token y logout; más CORS, métodos no permitidos y una ruta inexistente, para
  comprobar que el BFF no se cae. Los payloads son los mismos que envía
  `mobile/lib/services/auth_service.dart`.

  Exige Phoenix en 4001 y el BFF en 4000.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\prueba_e2e.ps1
#>
$ErrorActionPreference = 'Stop'
$bff = 'http://127.0.0.1:4000'
$fallos = 0

function Paso($n, $txt) { Write-Host "`n[$n] $txt" -ForegroundColor Cyan }
function Ok($txt, $det) { Write-Host ("   OK   {0}{1}" -f $txt, $(if ($det) { " -> $det" } else { '' })) -ForegroundColor Green }
function Mal($txt, $det) { Write-Host ("   FALLO {0} -> {1}" -f $txt, $det) -ForegroundColor Red; $script:fallos++ }

# Helper que replica ApiClient._verificar() de la app: devuelve StatusCode y Body.
function Llamar($Metodo, $Ruta, $Cuerpo, $Token) {
  $h = @{}
  if ($Token) { $h['Authorization'] = "Bearer $Token" }
  $a = @{ Uri = "$script:bff$Ruta"; Method = $Metodo; UseBasicParsing = $true; TimeoutSec = 20; Headers = $h }
  if ($Cuerpo) { $a.Body = $Cuerpo; $a.ContentType = 'application/json' }
  try {
    $r = Invoke-WebRequest @a
    return @{ Codigo = $r.StatusCode; Cuerpo = $r.Content }
  } catch {
    if ($_.Exception.Response) {
      # Invoke-WebRequest ya se ha comido el stream: hay que rebobinarlo antes
      # de leerlo, si no el cuerpo llega vacío en los 4xx y los 5xx.
      $stream = $_.Exception.Response.GetResponseStream()
      if ($stream.CanSeek) { $stream.Position = 0 }
      $cuerpo = (New-Object System.IO.StreamReader $stream).ReadToEnd()
      return @{ Codigo = [int]$_.Exception.Response.StatusCode; Cuerpo = $cuerpo }
    }
    throw
  }
}

Paso 1 'POST /api/user/signin (registro, como hace auth_service.registrarse)'
$usuario = "prueba$([DateTime]::Now.ToString('yyyyMMddHHmmss'))"
$r = Llamar POST '/api/user/signin' (@{ user = $usuario; password = 'secret123'; confirm_password = 'secret123' } | ConvertTo-Json -Compress) $null
if ($r.Codigo -in 200, 201) {
  $j = $r.Cuerpo | ConvertFrom-Json
  if ($j.data.token) { Ok "signin $($r.Codigo)" "token=$($j.data.token) user=$($j.data.user.user)" }
  else { Mal 'signin' "sin data.token: $($r.Cuerpo)" }
} else { Mal 'signin' "$($r.Codigo) $($r.Cuerpo)" }

Paso 2 'POST /api/user/login (como hace auth_service._iniciarSesionBff)'
$r = Llamar POST '/api/user/login' (@{ user = $usuario; password = 'secret123' } | ConvertTo-Json -Compress) $null
$token = $null
if ($r.Codigo -eq 200) {
  $j = $r.Cuerpo | ConvertFrom-Json
  if ($j.data.token) { $token = $j.data.token; Ok 'login 200' "token=$token" }
  else { Mal 'login' "sin data.token: $($r.Cuerpo)" }
} else { Mal 'login' "$($r.Codigo) $($r.Cuerpo)" }

Paso 3 'GET /api/user/me con Bearer (como hace auth_service._verificarSesion)'
if (-not $token) { Mal 'me' 'sin token, se omite' }
else {
  $r = Llamar GET '/api/user/me' $null $token
  if ($r.Codigo -eq 200) {
    $j = $r.Cuerpo | ConvertFrom-Json
    if ($j.user.user) { Ok 'me 200' "user=$($j.user.user)" }
    else { Mal 'me' "sin user: $($r.Cuerpo)" }
  } else { Mal 'me' "$($r.Codigo) $($r.Cuerpo)" }
}

Paso 4 'GET /api/user/me SIN token (la app debe limpiar la sesion con 401)'
$r = Llamar GET '/api/user/me' $null $null
if ($r.Codigo -eq 401) { Ok 'me sin token 401' } else { Mal 'me sin token' "$($r.Codigo) $($r.Cuerpo)" }

Paso 5 'DELETE /api/user/logout con Bearer (como hace auth_service.cerrarSesion)'
if (-not $token) { Mal 'logout' 'sin token, se omite' }
else {
  # Phoenix contesta 204 (sin contenido); la app no mira el código, solo que
  # no haya error, así que se acepta 200 y 204 como hace smoke-bff.ps1.
  $r = Llamar DELETE '/api/user/logout' $null $token
  if ($r.Codigo -in 200, 204) { Ok "logout $($r.Codigo)" } else { Mal 'logout' "$($r.Codigo) $($r.Cuerpo)" }
}

Paso 6 'CORS: preflight desde un origen de Flutter Web'
$resp = Invoke-WebRequest -Uri "$bff/api/user/login" -Method OPTIONS -UseBasicParsing -TimeoutSec 10 -Headers @{ Origin = 'http://localhost:53421' }
if ($resp.StatusCode -eq 204 -and $resp.Headers['access-control-allow-origin'] -eq '*') { Ok 'preflight 204' 'allow-origin: *' }
else { Mal 'preflight' "$($resp.StatusCode) $($resp.Headers['access-control-allow-origin'])" }

Paso 7 'Metodos no permitidos (405 con mensaje)'
$r = Llamar POST '/api/user/me' '{}' $null
if ($r.Codigo -eq 405 -and $r.Cuerpo -match 'permitido') { Ok 'POST /api/user/me 405' $r.Cuerpo }
else { Mal '405' "$($r.Codigo) $($r.Cuerpo)" }

Paso 8 'Ruta inexistente (el BFF no debe caerse)'
try { $r = Llamar GET '/api/esto/no/existe' $null $null; if ($r.Codigo -eq 404) { Ok '404' } else { Mal 'ruta inexistente' "$($r.Codigo)" } }
catch { Mal 'ruta inexistente' $_.Exception.Message }

Paso 9 'El BFF sigue vivo tras todo lo anterior'
try { $r = Invoke-WebRequest -Uri "$bff/" -UseBasicParsing -TimeoutSec 8; Ok 'GET / sigue 200' } catch { Mal 'salud final' $_.Exception.Message }

Write-Host ''
if ($fallos -eq 0) { Write-Host 'FLUJO COMPLETO OK' -ForegroundColor Green } else { Write-Host "$fallos FALLO(RES)" -ForegroundColor Red; exit 1 }
