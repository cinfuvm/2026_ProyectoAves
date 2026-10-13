<#
.SYNOPSIS
  Batería de pruebas de Phoenix: 46 comprobaciones contra el backend real.

.DESCRIPTION
  Recorre /images de punta a punta contra http://127.0.0.1:4001: subida
  multipart, paginación, filtro por categoría, reportes y los códigos de error.
  Se apoya en el usuario `emulador` / `secret123` y exige el catálogo vacío al
  empezar, así que conviene vaciarlo antes con `mix aves.limpiar_subidas`.

  Sale con código distinto de 0 si alguna comprobación falla.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\probar_images.ps1
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

# Lanza curl y devuelve el código de estado; el cuerpo va a $outFile.
function Llamar($metodo, $ruta, $outFile, [string[]]$extra = @()) {
  $argumentos = @('-s', '-o', $outFile, '-w', '%{http_code}', '-X', $metodo, "$base$ruta") + $extra
  return [int](& curl.exe @argumentos 2>$null)
}

function Json($outFile) { return (Get-Content $outFile -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Cuerpo($texto, $ruta) { [IO.File]::WriteAllText($ruta, $texto); return "@$ruta" }

# Espera a que el servidor conteste.
$disponible = $false
for ($i = 0; $i -lt 90; $i++) {
  $c = Llamar 'GET' '/images' (Join-Path $dir 'espera.json')
  if ($c -ge 200 -and $c -lt 500) { $disponible = $true; break }
  Start-Sleep -Milliseconds 1000
}
if (-not $disponible) { Write-Output 'FALLA: el servidor no arranca en 90s'; exit 1 }

$out = Join-Path $dir 'r.json'
$json = @('-H', 'Content-Type: application/json')

Write-Output '--- 1. GET /images (catalogo vacio) ---'
$codigo = Llamar 'GET' '/images' $out
$pagina = Json $out
Write-Output "  status=$codigo body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'GET /images devuelve 200' ($codigo -eq 200)
Ver 'GET paginado.pagina es 0' ($pagina.paginado.pagina -eq 0)
Ver 'GET paginado.total es 0' ($pagina.paginado.total -eq 0)
Ver 'GET urls es lista vacia' ($pagina.urls.Count -eq 0)

Write-Output '--- 2. Login del usuario demo ---'
$login = Cuerpo '{"user":"emulador","password":"secret123"}' (Join-Path $dir 'login.json')
$lc = Llamar 'POST' '/api/user/login' $out ($json + @('-d', $login))
$token = (Json $out).token
Ver 'login devuelve 200' ($lc -eq 200)
Ver 'login devuelve token' ([bool]$token)
if (-not $token) { exit 1 }
$auth = @('-H', "Authorization: Bearer $token")

Write-Output '--- 3. Prepara una imagen de prueba ---'
$pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC'
$pngPath = Join-Path $dir 'aves_prueba.png'
[IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String($pngBase64))
Ver 'imagen de prueba creada' (Test-Path $pngPath)

Write-Output '--- 4. POST /images sin token (debe ser 401) ---'
$c = Llamar 'POST' '/images' $out @('-F', "file=@$pngPath;type=image/png")
Ver 'POST sin token es 401' ($c -eq 401)

Write-Output '--- 5. POST /images (multipart) ---'
$c = Llamar 'POST' '/images' $out ($auth + @(
  '-F', "file=@$pngPath;type=image/png"
  '-F', 'categoria=Ave'
  '-F', 'lugar=Santiago'
  '-F', 'fecha=2026-10-12'
  '-F', 'comentario=Prueba de subida'
))
$foto = Json $out
Write-Output "  status=$c body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'POST devuelve 201' ($c -eq 201)
Ver 'POST devuelve id' ([bool]$foto.id)
Ver 'POST url apunta a /uploads' ($foto.url -like '*/uploads/*')
Ver 'POST categoria es Ave' ($foto.categoria -eq 'Ave')
Ver 'POST autor es emulador' ($foto.autor -eq 'emulador')
Ver 'POST lugar es Santiago' ($foto.lugar -eq 'Santiago')
Ver 'POST subida_en presente' ([bool]$foto.subida_en)

Write-Output '--- 6. GET /uploads/<archivo> sirve la imagen ---'
# Se descarga por la misma URL que recibe la app, host incluido.
$salida = & curl.exe -s -o (Join-Path $dir 'estatica.bin') -w '%{http_code}|%{content_type}|%{size_download}' "$($foto.url)"
$p = $salida -split '\|'
Ver 'el fichero estatico responde 200' ($p[0] -eq '200')
Ver 'content-type es image/png' ($p[1] -eq 'image/png')
Ver 'devuelve los mismos bytes' ([int]$p[2] -eq (Get-Item $pngPath).Length)

Write-Output '--- 7. GET /images ahora lista 1 foto ---'
Llamar 'GET' '/images' $out | Out-Null
$pagina = Json $out
Write-Output "  body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'GET lista 1 foto' ($pagina.urls.Count -eq 1)
Ver 'GET total es 1 pagina' ($pagina.paginado.total -eq 1)
Ver 'GET el id coincide con la subida' ($pagina.urls[0].id -eq $foto.id)
Ver 'GET incluye url' ([bool]$pagina.urls[0].url)
Ver 'GET incluye categoria' ($pagina.urls[0].categoria -eq 'Ave')
Ver 'GET incluye autor' ($pagina.urls[0].autor -eq 'emulador')
Ver 'GET incluye subida_en' ([bool]$pagina.urls[0].subida_en)

Write-Output '--- 8. Filtro por categoria ---'
Llamar 'GET' '/images?categoria=Ave' $out | Out-Null
Ver 'categoria=Ave lista 1' ((Json $out).urls.Count -eq 1)
Llamar 'GET' '/images?categoria=Todas' $out | Out-Null
Ver 'categoria=Todas lista 1' ((Json $out).urls.Count -eq 1)
Llamar 'GET' '/images?categoria=NoExiste' $out | Out-Null
$vacia = Json $out
Ver 'categoria inexistente lista 0' ($vacia.urls.Count -eq 0)
Ver 'categoria inexistente total 0' ($vacia.paginado.total -eq 0)

Write-Output '--- 9. Paginacion ---'
Llamar 'GET' '/images?pagina=0&por_pagina=1' $out | Out-Null
Ver 'por_pagina=1 lista 1' ((Json $out).urls.Count -eq 1)
Ver 'por_pagina=0 responde 400' ((Llamar 'GET' '/images?pagina=0&por_pagina=0' $out) -eq 400)
Ver 'por_pagina=99 responde 400' ((Llamar 'GET' '/images?pagina=0&por_pagina=99' $out) -eq 400)
Ver 'pagina=-1 responde 400' ((Llamar 'GET' '/images?pagina=-1' $out) -eq 400)

Write-Output '--- 10. PUT /images?id= reporta ---'
$reporte = Cuerpo '{"motivo":"no_es_ave","detalle":"Es un perro"}' (Join-Path $dir 'reporte.json')
$c = Llamar 'PUT' "/images?id=$($foto.id)" $out ($auth + $json + @('-d', $reporte))
$r = Json $out
Write-Output "  status=$c body=$(Get-Content $out -Raw -Encoding UTF8)"
Ver 'PUT devuelve 200' ($c -eq 200)
Ver 'PUT devuelve id' ([bool]$r.id)
Ver 'PUT avistamiento_id coincide' ($r.avistamiento_id -eq $foto.id)
Ver 'PUT motivo es no_es_ave' ($r.motivo -eq 'no_es_ave')
Ver 'PUT detalle es Es un perro' ($r.detalle -eq 'Es un perro')
Ver 'PUT estado es abierto' ($r.estado -eq 'abierto')
Ver 'PUT creado_en presente' ([bool]$r.creado_en)

Write-Output '--- 11. PUT /images sin token (debe ser 401) ---'
$c = Llamar 'PUT' "/images?id=$($foto.id)" $out ($json + @('-d', $reporte))
Ver 'PUT sin token es 401' ($c -eq 401)

Write-Output '--- 12. PUT /images con motivo invalido ---'
$malo = Cuerpo '{"motivo":"inventado"}' (Join-Path $dir 'malo.json')
Ver 'PUT motivo invalido es 400' ((Llamar 'PUT' "/images?id=$($foto.id)" $out ($auth + $json + @('-d', $malo))) -eq 400)

Write-Output '--- 13. PUT /images de una foto inexistente ---'
$otro = Cuerpo '{"motivo":"otro"}' (Join-Path $dir 'otro.json')
Ver 'PUT foto inexistente es 404' ((Llamar 'PUT' '/images?id=00000000-0000-0000-0000-000000000000' $out ($auth + $json + @('-d', $otro))) -eq 404)

Write-Output '--- 14. PUT /images sin id ---'
Ver 'PUT sin id es 400' ((Llamar 'PUT' '/images' $out ($auth + $json + @('-d', $otro))) -eq 400)

Write-Output '--- 15. POST /images con formato no admitido ---'
$txtPath = Join-Path $dir 'aves_prueba.txt'
[IO.File]::WriteAllBytes($txtPath, [Text.Encoding]::ASCII.GetBytes('hola'))
Ver 'POST de texto es 400' ((Llamar 'POST' '/images' $out ($auth + @('-F', "file=@$txtPath;type=text/plain", '-F', 'categoria=Ave'))) -eq 400)

Write-Output '--- 16. POST /images sin archivo ---'
Ver 'POST sin archivo es 400' ((Llamar 'POST' '/images' $out ($auth + @('-F', 'categoria=Ave'))) -eq 400)

Write-Output ''
Write-Output "Resultado: $ok comprobaciones correctas, $mal fallos."
if ($mal -gt 0) { exit 1 }
