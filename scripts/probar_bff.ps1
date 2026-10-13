<#
.SYNOPSIS
  Batería de pruebas del BFF: 29 comprobaciones contra http://127.0.0.1:4000.

.DESCRIPTION
  Comprueba que el BFF hace de proxy sin romper nada: login y perfil con la
  forma que espera la app (`{data:{token,user:{user}}}`), el multipart de
  /images, el reporte por PUT y los errores que reenvía tal cual (401, 404,
  400, 405).

  Exige Phoenix en 4001 y el catálogo vacío al empezar.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\probar_bff.ps1
#>
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:4000'
$estatico = 'http://127.0.0.1:4001'
$dir = Join-Path $env:TEMP 'aves_pruebas_bff'
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

$out = Join-Path $dir 'r.json'
$json = @('-H', 'Content-Type: application/json')

Write-Output '--- 1. Login a traves del BFF ---'
$login = Cuerpo '{"user":"emulador","password":"secret123"}' (Join-Path $dir 'login.json')
$lc = Llamar 'POST' '/api/user/login' $out ($json + @('-d', $login))
$envoltorio = Json $out
$token = $envoltorio.data.token
Ver 'el BFF devuelve 200' ($lc -eq 200)
Ver 'el BFF envuelve en data' ([bool]$envoltorio.data)
Ver 'el BFF devuelve token' ([bool]$token)
Ver 'el BFF devuelve user.user' ($envoltorio.data.user.user -eq 'emulador')
if (-not $token) { exit 1 }
$auth = @('-H', "Authorization: Bearer $token")

Write-Output '--- 2. GET /images a traves del BFF ---'
$codigo = Llamar 'GET' '/images' $out
$pagina = Json $out
Write-Output "  status=$codigo body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'GET a traves del BFF es 200' ($codigo -eq 200)
Ver 'GET trae paginado' ($null -ne $pagina.paginado)
Ver 'GET trae urls' ($null -ne $pagina.urls)

Write-Output '--- 3. Prepara una imagen de prueba ---'
$pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC'
$pngPath = Join-Path $dir 'aves_bff.png'
[IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String($pngBase64))
Ver 'imagen de prueba creada' (Test-Path $pngPath)

Write-Output '--- 4. POST /images multipart a traves del BFF ---'
$c = Llamar 'POST' '/images' $out ($auth + @(
  '-F', "file=@$pngPath;type=image/png"
  '-F', 'categoria=Ave'
  '-F', 'lugar=Valparaiso'
  '-F', 'fecha=2026-10-12'
  '-F', 'comentario=Subida por el BFF'
))
$foto = Json $out
Write-Output "  status=$c body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'el multipart sobrevive el BFF (201)' ($c -eq 201)
Ver 'devuelve id' ([bool]$foto.id)
Ver 'devuelve url' ([bool]$foto.url)
Ver 'categoria llega intacta' ($foto.categoria -eq 'Ave')
Ver 'lugar llega intacto' ($foto.lugar -eq 'Valparaiso')
Ver 'comentario llega intacto' ($foto.comentario -eq 'Subida por el BFF')
Ver 'autor es emulador' ($foto.autor -eq 'emulador')

Write-Output '--- 5. El navegador carga la imagen devuelta ---'
if ($foto.url) {
  $nombre = Split-Path $foto.url -Leaf
  $salida = & curl.exe -s -o (Join-Path $dir 'estatica.bin') -w '%{http_code}|%{content_type}|%{size_download}' "$estatico/uploads/$nombre"
  $p = $salida -split '\|'
  Ver 'la imagen se sirve con 200' ($p[0] -eq '200')
  Ver 'content-type es image/png' ($p[1] -eq 'image/png')
  Ver 'lleva los mismos bytes' ([int]$p[2] -eq (Get-Item $pngPath).Length)
} else {
  Ver 'la imagen se sirve con 200' $false
}

Write-Output '--- 6. GET /images ahora lista la foto ---'
Llamar 'GET' '/images' $out | Out-Null
$pagina = Json $out
Ver 'GET lista 1 foto' ($pagina.urls.Count -eq 1)
Ver 'GET el id coincide' ($pagina.urls[0].id -eq $foto.id)

Write-Output '--- 7. PUT /images?id= reporta a traves del BFF ---'
$reporte = Cuerpo '{"motivo":"derechos_autor","detalle":"No es tuya"}' (Join-Path $dir 'reporte.json')
$c = Llamar 'PUT' "/images?id=$($foto.id)" $out ($auth + $json + @('-d', $reporte))
$r = Json $out
Write-Output "  status=$c body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'PUT a traves del BFF es 200' ($c -eq 200)
Ver 'PUT motivo llega intacto' ($r.motivo -eq 'derechos_autor')
Ver 'PUT estado es abierto' ($r.estado -eq 'abierto')
Ver 'PUT avistamiento_id coincide' ($r.avistamiento_id -eq $foto.id)

Write-Output '--- 8. Errores que el BFF reenvia tal cual ---'
Ver 'POST sin token es 401' ((Llamar 'POST' '/images' $out @('-F', "file=@$pngPath;type=image/png")) -eq 401)
Ver 'PUT sin token es 401' ((Llamar 'PUT' "/images?id=$($foto.id)" $out ($json + @('-d', $reporte))) -eq 401)
Ver 'PUT foto inexistente es 404' ((Llamar 'PUT' '/images?id=00000000-0000-0000-0000-000000000000' $out ($auth + $json + @('-d', $reporte))) -eq 404)
Ver 'GET por_pagina=0 es 400' ((Llamar 'GET' '/images?pagina=0&por_pagina=0' $out) -eq 400)
Ver 'DELETE /images es 405' ((Llamar 'DELETE' '/images' $out) -eq 405)

Write-Output ''
Write-Output "Resultado: $ok comprobaciones correctas, $mal fallos."
if ($mal -gt 0) { exit 1 }
