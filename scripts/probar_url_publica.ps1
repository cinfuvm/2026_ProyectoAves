<#
.SYNOPSIS
  Comprueba que la URL pública de las fotos usa la IP de LAN y que se descarga.

.DESCRIPTION
  Phoenix publica las fotos subidas en `:url_publica`. No puede ser 127.0.0.1
  porque desde el emulador ese 127.0.0.1 es el propio emulador, así que por
  defecto el servidor detecta la IP privada de la red local al arrancar.

  Aquí se detecta con el mismo criterio (192.168 por delante; después 172.16-31
  y 10, que suelen ser Docker o VPN y no llegan a la app) y se verifica que el
  servidor haya elegido la misma. Después descarga la foto desde el PC y desde
  el emulador, que es lo que tiene que poder hacer la app.

  Si tu red cambia no hace falta tocar nada: al arrancar Phoenix detecta la IP
  nueva, y este script vuelve a detectarla con el mismo criterio.

  La comprobación desde el emulador usa toybox (printf + nc) porque el shell de
  Android no trae ni curl ni wget; con eso se hace una petición HTTP de verdad,
  igual que la haría la app al pintar la foto.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\probar_url_publica.ps1
#>
[CmdletBinding()]
param(
  [int]$Puerto = 4001,
  [string]$Login = 'http://127.0.0.1:4000'
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP 'aves_pruebas'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$out = Join-Path $dir 'url.json'

$ipLan = $null
foreach ($rango in '^192\.168\.', '^172\.(1[6-9]|2[0-9]|3[01])\.', '^10\.') {
  $candidata = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -match $rango } |
    Select-Object -First 1 -ExpandProperty IPAddress
  if ($candidata) { $ipLan = $candidata; break }
}
if (-not $ipLan) { Write-Output 'FALLA: esta maquina no tiene IP privada de LAN'; exit 1 }
$prefijo = "http://${ipLan}:$Puerto/uploads/"
Write-Output "ip de LAN detectada: $ipLan"

$token = $null
$loginJson = Join-Path $dir 'login.json'
[IO.File]::WriteAllText($loginJson, '{"user":"emulador","password":"secret123"}')
for ($i = 0; $i -lt 90; $i++) {
  $codigo = [int](& curl.exe -s -o $out -w '%{http_code}' -X POST "$Login/api/user/login" -H 'Content-Type: application/json' -d "@$loginJson" 2>$null)
  if ($codigo -eq 200) { $token = (Get-Content $out -Raw | ConvertFrom-Json).data.token; break }
  Start-Sleep -Milliseconds 1000
}
if (-not $token) { Write-Output "FALLA: no hay BFF en $Login"; exit 1 }

$pngPath = Join-Path $dir 'aves_prueba.png'
[IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC'))
$codigo = & curl.exe -s -o $out -w '%{http_code}' -X POST "$Login/images" `
  -H "Authorization: Bearer $token" `
  -F "file=@$pngPath;type=image/png" -F 'categoria=Ave'

$foto = Get-Content $out -Raw | ConvertFrom-Json
Write-Output "status=$codigo"
Write-Output "url=$($foto.url)"

if ($foto.url -like "$prefijo*") { Write-Output 'OK   la URL publica usa la IP de LAN' } else { Write-Output "FALLA la URL no empieza por $prefijo"; exit 1 }

# El PC debe poder descargarla por esa misma URL.
$salida = & curl.exe -s -o (Join-Path $dir 'lan.bin') -w '%{http_code}|%{content_type}|%{size_download}' $foto.url
$p = $salida -split '\|'
Write-Output "descarga por LAN: $salida"
if ($p[0] -eq '200' -and [int]$p[2] -eq (Get-Item $pngPath).Length) { Write-Output 'OK   el PC la descarga por la IP de LAN' } else { Write-Output 'FALLA descarga por LAN'; exit 1 }

# Y el emulador debe poder hacer lo mismo: es donde corre la app.
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source }
if (-not $adb) { Write-Output 'OMITIDO emulador: no hay adb en esta maquina'; exit 0 }
$dispositivos = (& $adb devices) -join "`n"
if ($dispositivos -notmatch 'emulator-\d+\s+device') {
  Write-Output 'OMITIDO emulador: ninguno conectado (arrancale y vuelve a lanzar)'
  exit 0
}

$ruta = ([Uri]$foto.url).AbsolutePath
$peticion = "toybox printf 'GET $ruta HTTP/1.0\r\nHost: ${ipLan}\r\nConnection: close\r\n\r\n' | toybox nc -w 10 $ipLan $Puerto"
$respuesta = (& $adb shell $peticion 2>&1 | Out-String)

if ($respuesta -notmatch 'HTTP/' -and $respuesta -match 'toybox:|not found|inaccessible') {
  Write-Output "OMITIDO emulador: el sistema no trae los binarios necesarios ($($respuesta.Trim()))"
  exit 0
}

$estado = if ($respuesta -match 'HTTP/\d\.\d\s+(\d{3})') { $Matches[1] } else { '' }
$longitud = if ($respuesta -match '(?im)^\s*content-length:\s*(\d+)') { [int]$Matches[1] } else { $null }
Write-Output "respuesta desde el emulador: HTTP $estado  content-length=$longitud"

$bytesOriginales = (Get-Item $pngPath).Length
if ($estado -eq '200' -and $longitud -eq $bytesOriginales) {
  Write-Output 'OK   el emulador descarga la foto por la IP de LAN'
} elseif ($estado -eq '200') {
  Write-Output "FALLA el emulador la pide y recibe $longitud bytes, pero la foto pesa $bytesOriginales"
  exit 1
} else {
  Write-Output "FALLA desde el emulador: HTTP $estado o sin respuesta"
  exit 1
}
