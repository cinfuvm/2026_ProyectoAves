<#
.SYNOPSIS
  12 comprobaciones del espejado de subidas entre las dos carpetas de uploads.

.DESCRIPTION
  Cada foto se guarda en `priv/static/uploads` (el origen) y en
  `_build/dev/lib/aves/priv/static/uploads` (la que sirve Phoenix, que en
  Windows se regenera al compilar). Comprueba que las dos se escriben, que la
  foto se descarga por la URL pública, y que si borras la de `_build`,
  `mix compile` la recupera.

  Se cambia solo al directorio de backend/aves, así que se lanza desde
  cualquier sitio.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\probar_espejo.ps1
#>
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:4001'
$dir = Join-Path $env:TEMP 'aves_pruebas'
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$ok = 0
$mal = 0
function Ver($etiqueta, $condicion) {
  if ($condicion) { $script:ok += 1 } else { $script:mal += 1 }
  $marca = if ($condicion) { 'OK  ' } else { 'FALLA' }
  Write-Output "$marca $etiqueta"
}

function Llamar($metodo, $ruta, $outFile, [string[]]$extra = @()) {
  $argumentos = @('-s', '-o', $outFile, '-w', '%{http_code}', '-X', $metodo, "$base$ruta") + $extra
  return [int](& curl.exe @argumentos 2>$null)
}

function Json($outFile) { return (Get-Content $outFile -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Cuerpo($texto, $ruta) { [IO.File]::WriteAllText($ruta, $texto); return "@$ruta" }

# Mira ficheros en disco y ejecuta `mix compile`, así que trabaja contra
# backend/aves sin importar desde dónde se lance el script.
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) 'backend\aves')

$origen = (Resolve-Path 'priv\static\uploads' -ErrorAction SilentlyContinue)
$servida = '_build\dev\lib\aves\priv\static\uploads'

$out = Join-Path $dir 'e.json'
$json = @('-H', 'Content-Type: application/json')

Write-Output '--- login ---'
$login = Cuerpo '{"user":"emulador","password":"secret123"}' (Join-Path $dir 'login.json')
$lc = Llamar 'POST' '/api/user/login' $out ($json + @('-d', $login))
$token = (Json $out).token
Ver 'login 200' ($lc -eq 200)
if (-not $token) { exit 1 }
$auth = @('-H', "Authorization: Bearer $token")

Write-Output '--- imagen de prueba ---'
$png = Join-Path $dir 'espejo.png'
[IO.File]::WriteAllBytes($png, [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC'))
Ver 'png creado' (Test-Path $png)

Write-Output '--- subida POST /images ---'
$cuerpo = @(
  '-H', "Authorization: Bearer $token",
  '-F', "categoria=Espejo",
  '-F', "file=@$png;type=image/png"
)
$codigo = Llamar 'POST' '/images' $out $cuerpo
$registro = Json $out
Write-Output "  status=$codigo url=$($registro.url)"
Ver 'POST 201' ($codigo -eq 201)
$nombre = [IO.Path]::GetFileName([string]$registro.url)
Ver 'la respuesta trae url con nombre' ([bool]$nombre)

Write-Output '--- las dos carpetas ---'
$enOrigen = Join-Path 'priv\static\uploads' $nombre
$enServida = Join-Path $servida $nombre
Write-Output "  origen : $enOrigen -> $(Test-Path $enOrigen)"
Write-Output "  servida: $enServida -> $(Test-Path $enServida)"
Ver 'el fichero esta en priv/static/uploads (origen)' (Test-Path $enOrigen)
Ver 'el fichero esta en _build/.../uploads (servida)' (Test-Path $enServida)

Write-Output '--- la url publica responde ---'
$descarga = Join-Path $dir 'descarga.png'
$dc = Llamar 'GET' ([string]$registro.url -replace '^https?://[^/]+', '') $descarga
Ver 'GET de la foto 200' ($dc -eq 200)
Ver 'descarga igual al original' ((Get-FileHash $descarga).Hash -eq (Get-FileHash $png).Hash)

Write-Output '--- simulamos limpiar _build ---'
if (Test-Path $enServida) { Remove-Item $enServida -Force }
Ver 'la servida desaparece' (-not (Test-Path $enServida))
Ver 'el origen sigue ahi' (Test-Path $enOrigen)

Write-Output '--- mix compile recupera la copia ---'
mix compile 2>&1 | Out-Null
Ver 'mix compile la recupera en _build' (Test-Path $enServida)

$dc2 = Llamar 'GET' ([string]$registro.url -replace '^https?://[^/]+', '') $descarga
Ver 'la foto vuelve a responder 200' ($dc2 -eq 200)

Write-Output ''
Write-Output "RESULTADO: $ok correctas, $mal fallos"
if ($mal -gt 0) { exit 1 }
