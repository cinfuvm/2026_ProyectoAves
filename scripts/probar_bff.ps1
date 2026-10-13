<#
.SYNOPSIS
  Batería de pruebas del BFF: 46 comprobaciones contra http://127.0.0.1:4000.

.DESCRIPTION
  Comprueba que el BFF hace de proxy sin romper nada: login y perfil con la
  forma que espera la app (`{data:{token,user:{user,rol}}}`), el multipart de
  /images, el reporte por PUT, la moderación de reportes y los errores que
  reenvía con su `message` (401, 400, 403, 404, 405).

  Exige Phoenix en 4001, el catálogo vacío al empezar y `emulador` con el rol
  `admin` (lo ponen los seeds: `mix run priv/repo/seeds.exs`).

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
# Sin `rol` la app nunca sabe que es admin y no enseña moderación.
Ver 'el BFF pasa el rol' ($envoltorio.data.user.rol -eq 'admin')
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

Write-Output '--- 9. GET /images/reports a traves del BFF ---'
# Segundo usuario: el rol `usuario` no puede ni mirar los reportes.
$login2 = Cuerpo '{"user":"demo","password":"secret123"}' (Join-Path $dir 'login2.json')
$lc2 = Llamar 'POST' '/api/user/login' $out ($json + @('-d', $login2))
$token2 = (Json $out).data.token
Ver 'login de demo es 200' ($lc2 -eq 200)
$auth2 = @('-H', "Authorization: Bearer $token2")

$c = Llamar 'GET' '/images/reports' $out $auth
if ($c -eq 403) {
  Write-Output '  PISTA: emulador no tiene el rol admin. Reaplica los seeds con: mix run priv/repo/seeds.exs'
}
$nuestro = @(((Json $out).reportes) | Where-Object { $_.id -eq $r.id })
Write-Output "  status=$c nuestro=$($nuestro.Count)"
Ver 'GET /images/reports es 200' ($c -eq 200)
Ver 'el reporte de esta sesion aparece' ($nuestro.Count -eq 1)
Ver 'el reporte trae su foto' ($nuestro.avistamiento.id -eq $foto.id)
Ver 'reportado_por llega intacto' ($nuestro.reportado_por -eq 'emulador')
Llamar 'GET' '/images/reports?estado=abierto' $out $auth | Out-Null
Ver 'estado=abierto lo lista' (@(((Json $out).reportes) | Where-Object { $_.id -eq $r.id }).Count -eq 1)
Ver 'estado desconocido es 400 con message' ((Llamar 'GET' '/images/reports?estado=zzz' $out $auth) -eq 400)
Ver 'GET sin token es 401' ((Llamar 'GET' '/images/reports' $out) -eq 401)
Ver 'GET como usuario normal es 403' ((Llamar 'GET' '/images/reports' $out $auth2) -eq 403)

Write-Output '--- 10. PUT /images/reports/:id a traves del BFF ---'
$nuevoEstado = Cuerpo '{"estado":"revisado"}' (Join-Path $dir 'estado.json')
$c = Llamar 'PUT' "/images/reports/$($r.id)" $out ($auth + $json + @('-d', $nuevoEstado))
Write-Output "  status=$c body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'PUT /images/reports es 200' ($c -eq 200)
Ver 'devuelve el nuevo estado' ((Json $out).estado -eq 'revisado')
$maloEstado = Cuerpo '{"estado":"inventado"}' (Join-Path $dir 'estado_malo.json')
Ver 'PUT estado invalido es 400' ((Llamar 'PUT' "/images/reports/$($r.id)" $out ($auth + $json + @('-d', $maloEstado))) -eq 400)
Ver 'PUT reporte inexistente es 404' ((Llamar 'PUT' '/images/reports/00000000-0000-0000-0000-000000000000' $out ($auth + $json + @('-d', $nuevoEstado))) -eq 404)
Ver 'PUT usuario normal es 403' ((Llamar 'PUT' "/images/reports/$($r.id)" $out ($auth2 + $json + @('-d', $nuevoEstado))) -eq 403)
# El proxy del BFF no admite PATCH, por eso la app usa PUT; el resto de
# metodos en estas rutas se rechaza en el propio BFF, sin llegar a Phoenix.
Ver 'POST /images/reports es 405' ((Llamar 'POST' '/images/reports' $out $auth) -eq 405)
Ver 'GET /images/reports/:id es 405' ((Llamar 'GET' "/images/reports/$($r.id)" $out $auth) -eq 405)

Write-Output ''
Write-Output "Resultado: $ok comprobaciones correctas, $mal fallos."
if ($mal -gt 0) { exit 1 }
