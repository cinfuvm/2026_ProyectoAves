# Conexión del frontend móvil con el backend `aves`

Guía para conectar la app Flutter (`mobile/`) con el backend Phoenix, que vive
en este repo en `backend/aves`.

## 1. Requisitos

- El backend Phoenix (`backend/aves`) corriendo: Puerto `4001` (el 4000 lo usa
  el BFF). Arranque completo en `LOCAL_SETUP.md`, punto 2.
- Flutter SDK para la app móvil.

## 2. Dónde corre el backend

Por defecto en la misma máquina (`http://127.0.0.1:4001`). Solo hay que saber
**a qué URL** está, y esa URL vive en una única variable de entorno del BFF:
`BACKEND_URL`.

Verificación rápida (cualquier respuesta del backend sirve; solo el error de
conexión indica un problema de red):

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:4001/api/user/login" -Method POST `
  -Body '{"email":"a@b.cl","password":"x"}' -ContentType 'application/json'
```

La app móvil no habla nunca directamente con el backend, solo con el BFF.
En dev Phoenix escucha en `0.0.0.0`, así que también es alcanzable por la IP
de LAN si el backend corriera en otra máquina.

## 3. URL base según entorno de prueba

La app apunta al **BFF** (`mobile/lib/config/api_config.dart`), que hace de
proxy del backend.

| Entorno | URL del BFF |
|---|---|
| Web / desktop | `http://127.0.0.1:4000` |
| Emulador Android | `http://10.0.2.2:4000` |
| Dispositivo físico (misma WiFi) | `http://192.168.x.x:4000` (IP local de la PC) |

La URL del BFF se overridea con `--dart-define=BFF_URL=...`; la del backend con
`BACKEND_URL` al arrancar el BFF. Procedimiento completo en `LOCAL_SETUP.md`.

> Las **fotos** no pasan por el BFF: su `url` apunta directamente a Phoenix
> (`/uploads/<archivo>`), construida con `PUBLIC_BASE_URL`. Ver
> `LOCAL_SETUP.md`, punto 8.

> Nota: en desarrollo usa HTTP sin TLS. Para pruebas en dispositivo físico hay
> que permitir tráfico cleartext en Android
> (`android:usesCleartextTraffic="true"` o un `network_security_config`).
> No usar en producción.

## 4. Endpoints de autenticación

Todos responden JSON y usan prefijo `/api`.

### `POST /api/user/signin` — registrar usuario

Request:

```json
{
  "email": "test@aves.cl",
  "nickname": "test",
  "password": "12345678",
  "confirm_password": "12345678"
}
```

- Acepta `user` como alias de `email`.
- Acepta `password_confirmation` como alias de `confirm_password`.
- Respuesta `201`:

```json
{
  "user": { "id": "...", "email": "test@aves.cl", "nickname": "test", "rol": "usuario" },
  "token": "..."
}
```

- `422` si la validación falla (`errors: [...]`).

### `POST /api/user/login` — iniciar sesión

Request:

```json
{ "email": "test@aves.cl", "password": "12345678" }
```

Respuesta `200`: misma estructura `user` + `token`.
Respuesta `401`: `{"error": "Credenciales inválidas"}`.

### `DELETE /api/user/logout` — cerrar sesión

Header: `Authorization: Bearer <token>`.

Respuesta `204` (sin cuerpo).

### `GET /api/user/me` — usuario autenticado

Header: `Authorization: Bearer <token>`.

Respuesta:

```json
{ "user": { "id": "...", "email": "test@aves.cl", "nickname": "test", "rol": "usuario" } }
```

Respuesta `401` si el token falta o es inválido.

### Lo que fija el BFF para la app móvil

El backend puede cambiar de forma por su coordinación con el equipo de web
(`birds_apis.yaml` admite tanto `{token, user}` plano como `{data:{...}}`, y
`user` puede ser string u objeto). El BFF reduce todo eso a **un único formato
estable** para la app:

| Ruta | Forma que recibe la app |
|---|---|
| `POST /api/user/signin`, `POST /api/user/login` | `{data: {token, user: {email, nickname}}}` |
| `GET /api/user/me` | `{user: {email, nickname}}` |

Si el backend manda otra forma, se arregla **solo en el BFF** (ver
`normalizarSesion` / `normalizarUsuario` en `bff/lib/backend.dart`). Sin token
en la respuesta, el cuerpo pasa tal cual para que el error llegue intacto.

## 5. Recursos de fotos (`/images`)

Son **passthrough puro**: el BFF no interpreta nada, reenvía método, cabeceras,
query string y cuerpo. El cuerpo va en **bytes crudos**, porque pasarlo por
texto rompería el `boundary` del multipart y el backend no leería el archivo.

| Petición | Notas |
|---|---|
| `GET /images?categoria=&pagina=&por_pagina=` | Query string conservada |
| `POST /images` | `multipart/form-data`, campo del archivo `file` |
| `PUT /images?id=` | Body JSON con `motivo` y `detalle`; el `id` va en la query |

### Implementado en Phoenix

`/images` está implementado en el propio backend
(`AvesWeb.API.ImageController`, recursos Ash `Aves.Media.Image` y
`Aves.Media.Report`, migración `add_image_catalogue`).

| Detalle | Comportamiento |
|---|---|
| `GET /images` | Público, sin token |
| `POST /images`, `PUT /images` | Requieren `Authorization: Bearer` (pipeline `:api_auth`) |
| `categoria=Todas`, vacía o ausente | Sin filtro |
| Otra `categoria` | Coincidencia exacta |
| `por_pagina` | Entre 1 y 50; `pagina` ≥ 0. Fuera de rango → **400** |
| `paginado.total` | **Número de páginas**, no de fotos (`ceil(fotos/por_pagina)`), para que `hayMas = pagina + 1 < total` sea correcto |
| Motivos válidos | `no_es_ave`, `contenido_ofensivo`, `imagen_enganosa`, `derechos_autor`, `otro`. Otro → **400** |
| Foto inexistente al reportar | **404** |
| Archivo | `file` en `multipart/form-data`, `image/*`, máx. 10 MB → **413** |
| Almacenamiento | `priv/static/uploads`, servido como `/uploads/<archivo>` (`uploads` está en `static_paths()`) |
| URL pública | Absoluta, desde `:url_publica` / `PUBLIC_BASE_URL` (ver `LOCAL_SETUP.md`) |

> No hay `DELETE /images`: el contrato `birds_apis.yaml` no lo incluye.

> **CORS pendiente.** Necesario cuando una web hable con Phoenix directamente;
> la app nativa y el emulador no lo usan.

## 6. Ejemplos con curl

Se prueban contra el **BFF** (puerto 4000). Para hablar directamente con el
backend, sustituye `http://127.0.0.1:4000` por `http://127.0.0.1:4001`.

```powershell
# Registrar
curl.exe -X POST http://127.0.0.1:4000/api/user/signin `
  -H "Content-Type: application/json" `
  -d '{"email":"test@aves.cl","nickname":"test","password":"12345678","confirm_password":"12345678"}'

# Login
curl.exe -X POST http://127.0.0.1:4000/api/user/login `
  -H "Content-Type: application/json" `
  -d '{"email":"test@aves.cl","password":"12345678"}'

# Perfil (reemplaza <TOKEN>)
curl.exe http://127.0.0.1:4000/api/user/me `
  -H "Authorization: Bearer <TOKEN>"

# Logout
curl.exe -X DELETE http://127.0.0.1:4000/api/user/logout `
  -H "Authorization: Bearer <TOKEN>"

# Colección de fotos (la query viaja entera al backend)
curl.exe "http://127.0.0.1:4000/images?categoria=ave&pagina=0&por_pagina=20"

# Subir foto (multipart; el campo del archivo es `file`)
curl.exe -X POST http://127.0.0.1:4000/images `
  -H "Authorization: Bearer <TOKEN>" `
  -F "file=@C:\ruta\ave.jpg;type=image/jpeg" -F "categoria=ave"

# Reportar foto
curl.exe -X PUT "http://127.0.0.1:4000/images?id=<FOTO_ID>" `
  -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" `
  -d '{"motivo":"no_es_ave","detalle":"Es un perro"}'
```

Automatizado: `powershell -ExecutionPolicy Bypass -File scripts\smoke-bff.ps1`.

## 7. Integración en Flutter

- `mobile/lib/services/auth_service.dart` debe cambiar de mock a HTTP:
  - `iniciarSesion` → `POST /api/user/login` (o `signin` para registro).
  - `obtenerSesion` → `GET /api/user/me` con token guardado.
  - `cerrarSesion` → `DELETE /api/user/logout`.
- Guardar `token` y `user` en `SharedPreferences` (o `flutter_secure_storage`).
- Enviar siempre `Authorization: Bearer <token>` en peticiones protegidas.
- Manejar errores:
  - `401` → cerrar sesión local y mostrar login.
  - `422` → mostrar mensajes de validación.
  - Timeouts / sin conexión → mensaje de reintento.

## 8. Diferencias con `birds_apis.yaml`

El contrato `birds_apis.yaml` difiere del backend real en puntos a conciliar:

| Contrato | Backend real | Cómo lo absorbe el BFF |
|---|---|---|
| `/user/login` | `/api/user/login` | La app llama a la ruta del BFF |
| `{token, user}` o `{data:{...}}` | `{user:{...}, token}` | Normaliza a `{data:{token,user:{...}}}` |
| `confirm_pasword` (typo) | `confirm_password` | La app ya envía el nombre real |
| Endpoints `/images` | Implementados en `AvesWeb.API.ImageController` | Passthrough; solo normaliza errores |

## 9. Pendientes del backend

- CORS (decidir con el equipo de web cuando actualicen Phoenix).
- Dominios registrados en `AvesWeb.AshJsonApiRouter` (hoy `domains: []`).
