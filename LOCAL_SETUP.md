# Arranque local: backend Phoenix + BFF + app móvil

Guía operativa para tener el **backend Phoenix**, el **BFF** y la **app móvil**
funcionando en la misma máquina y probar el flujo completo end-to-end.

## Arquitectura

```
app móvil  ──►  BFF (Dart Frog)  ──►  backend Phoenix  ──►  Postgres 17
 4000           0.0.0.0:4000          127.0.0.1:4001        local
```

El móvil **nunca** habla con el backend directamente: solo con el BFF. La
configuración relevante vive en tres sitios:

| Qué | Dónde |
|---|---|
| URL del BFF para el móvil | `mobile/lib/config/api_config.dart` (o `--dart-define=BFF_URL`) |
| URL del backend para el BFF | variable de entorno `BACKEND_URL` (por defecto `http://127.0.0.1:4001`) |
| URL pública bajo la que Phoenix sirve las fotos | `PUBLIC_BASE_URL` (ver punto 8) |

> Dart Frog **no** carga archivos `.env` (v1.2.14): `BACKEND_URL` se pasa como
> variable de entorno del proceso que arranca el BFF.

> **CORS sigue pendiente.** El navegador bloquearía hoy las llamadas directas a
> Phoenix desde cualquier web; la app nativa y el emulador no lo necesitan. Se
> decide cuando el equipo de web actualice Phoenix.

## 1. Requisitos

### Backend Phoenix (`backend/aves`)

- Elixir 1.17+ y Erlang/OTP (versión la que fije `mix.exs`).
- Postgres 17 con el servicio `postgresql-x64-17` arrancado.
- Phoenix, Ash y Ash PostgreSQL: se instalan con `mix deps.get`.

### App móvil y BFF

- Dart SDK y el CLI de Dart Frog:

  ```powershell
  dart pub global activate dart_frog_cli
  ```

- Flutter SDK para la app móvil.

## 2. Backend Phoenix local (127.0.0.1:4001)

El backend corre en esta misma máquina, en `backend/aves`.

### Primera puesta en marcha

```powershell
cd backend\aves
mix deps.get
mix ecto.create
mix ecto.migrate          # aplica las migraciones, incluida la de /images
mix run priv/repo/seeds.exs
```

> En Windows, Elixir **copia** `priv/` a `_build\dev\lib\aves\priv` en lugar
> de enlazarlo. Si borras una migración de `priv/`, sigue estando en la copia y
> Phoenix levanta `PendingMutationError`/migraciones pendientes fantasma:
> `Remove-Item _build\dev\lib\aves -Recurse -Force` y vuelve a compilar.

### Arranque

```powershell
cd backend\aves
$env:PORT = '4001'; mix phx.server
```

- El **4000 es del BFF**, así que `PORT` es obligatorio (el default de Phoenix
  es el 4000).
- En dev escucha en **todas las interfaces** (`config/dev.exs`, `ip: {0,0,0,0}`)
  para que el emulador y un celular físico puedan alcanzarlo por la IP de LAN.
- Usuarios de prueba: `emulador@aves.cl` y `demo@aves.cl`, contraseña
  `secret123` (los crea `priv/repo/seeds.exs`).

Comprobar que responde antes de seguir:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:4001/images" -UseBasicParsing
# y a través del BFF, que es lo que usa la app:
Invoke-WebRequest -Uri "http://127.0.0.1:4000/" -UseBasicParsing
```

### Si el backend sigue en otra máquina

Nada cambia en la app: el BFF solo lee `BACKEND_URL`, así que basta con
apuntarlo a esa máquina (`scripts\bff.ps1 -BackendUrl http://<IP>:4001`).

> **CORS sigue pendiente.** El BFF llama al backend por HTTP interno (sin
> navegador), así que hoy no hace falta. Hará falta cuando una web hable con
> Phoenix directamente; se decide con el equipo de web.

## 3. BFF (0.0.0.0:4000)

```powershell
# Opción A: script
powershell -ExecutionPolicy Bypass -File scripts\bff.ps1

# Opción B: manual (desde la carpeta bff/)
cd bff
$env:BACKEND_URL = 'http://127.0.0.1:4001'
dart_frog dev --hostname 0.0.0.0 --port 4000
```

- `--hostname 0.0.0.0` es **obligatorio** para probar desde el emulador o el
  celular; el default (`localhost`) solo sirve desde el PC.
- `BACKEND_URL` por defecto en el código: `http://127.0.0.1:4001`. Si no lo
  defines, el BFF asume backend local (útil con el mock del punto 5).
- Si necesitas correr el BFF **sin terminal interactiva** (script, CI, servicio),
  usa el build de producción, porque `dev` necesita una TTY para el hot reload:

  ```powershell
  cd bff
  dart_frog build
  $env:PORT = '4000'; $env:BACKEND_URL = 'http://127.0.0.1:4001'
  dart build\bin\server.dart
  ```

## 4. Verificación del BFF

```powershell
powershell -ExecutionPolicy Bypass -File scripts\smoke-bff.ps1
# Con el backend en otra máquina:
powershell -ExecutionPolicy Bypass -File scripts\smoke-bff.ps1 -BaseUrl http://127.0.0.1:4000
```

| Petición | Backend inalcanzable | Backend arriba |
|---|---|---|
| `GET /` | 200 + `backend.reachable:false` | 200 + `true` |
| `OPTIONS /api/user/login` | 204 + CORS | 204 |
| `POST /api/user/signin` | **502** | 201 |
| `POST /api/user/login` | **502** | 200 |
| `GET /api/user/me` | **502** | 200 / 401 |
| `DELETE /api/user/logout` | **502** | 200 |
| `POST /api/user/me` | 405 | 405 |
| `GET /images?categoria=&pagina=` | **502** | 200 |
| `POST /images` (multipart) | **502** | 201 |
| `PUT /images?id=` | **502** | 200 |

Un **502** siempre significa "el BFF no pudo alcanzar al backend": revisa
`BACKEND_URL` y la conectividad del punto 2. Si la petición se queda **sin
respuesta**, el problema está en el BFF o en el camino hasta él.

`GET /` reporta además `backend: {url, reachable}`: es lo primero que hay que
mirar cuando algo falla desde el celular, porque distingue "el BFF no corre"
de "el BFF corre pero no llega al backend".

### Prueba end-to-end en el dispositivo

Hay una prueba de integración que corre la app real en el emulador o en un
celular y la apunta al BFF: login por la UI y luego colección, subida multipart
y reporte usando el cliente HTTP y los parsers de la app.

```powershell
# BFF y backend arriba primero (puntos 2 y 3).
cd mobile
flutter test integration_test -d emulator-5554 --dart-define=BFF_ACTIVO=true
# Celular físico: cambia el dispositivo y pasa BFF_URL con la IP del PC.
```

Si el BFF no está alcanzable la prueba se **salta** en lugar de fallar, para
que no rompa un `flutter test` corriente.

## 5. Backend simulado (opcional)

Para desarrollar móvil y BFF sin arrancar Phoenix (punto 2):

```powershell
dart scripts\mock_backend.dart     # 0.0.0.0:4001  (--port para cambiar)
```

Devuelve usuarios falsos con el mismo formato que el backend real, más un
catálogo de fotos en `/images` (también acepta la subida multipart y el
reporte), así se puede probar el flujo completo sin backend. Deja el BFF con
el `BACKEND_URL` por defecto (`http://127.0.0.1:4001`) y ya está.

Cada petición queda registrada en la consola con su método, query y tamaño de
cuerpo, lo que sirve para comprobar que el multipart viaja entero.

## 6. App móvil

La URL del BFF se resuelve en `mobile/lib/config/api_config.dart`:

- `--dart-define=BFF_URL=...` → tiene prioridad sobre todo.
- Sin define, en Android usa `http://10.0.2.2:4000` (emulador).
- En el resto de plataformas usa `http://127.0.0.1:4000` (desktop).

Para que la app hable con el BFF real hay que desactivar el mock:

```powershell
--dart-define=BFF_ACTIVO=true
```

### Emulador de Android

```powershell
cd mobile
flutter run --dart-define=BFF_ACTIVO=true
```

`10.0.2.2` es el alias del `localhost` del PC desde dentro del emulador; ya es
el default, así que no hace falta `BFF_URL`.

### Celular físico (misma red)

`10.0.2.2` no existe en un celular real: hay que pasar la IP del PC que hace de
BFF (la del backend no sirve aquí).

```powershell
# 1. Ver la IP del PC (por ejemplo 192.168.1.2)
ipconfig | findstr IPv4

# 2. Arrancar la app apuntando a esa IP
cd mobile
flutter run --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://192.168.1.2:4000
```

El celular y el PC deben estar en la misma red (y sin aislamiento de cliente/
AP mode del router). Si no conecta, revisa el firewall de Windows: permite el
puerto **4000** en redes privadas.

### Desktop

```powershell
cd mobile
flutter run -d windows --dart-define=BFF_ACTIVO=true --dart-define=BFF_URL=http://127.0.0.1:4000
```

## 7. Flujo end-to-end de autenticación

1. Registro: `POST /api/user/signin` con `email`, `nickname`, `password`,
   `confirm_password` → `{data:{token, user}}`.
2. Login: `POST /api/user/login` con `email`, `password` → `{data:{token, user}}`.
3. Sesión: `GET /api/user/me` con `Authorization: Bearer <token>` → `{user:{...}}`.
4. Logout: `DELETE /api/user/logout` con el Bearer → revoca el token.

El BFF **fija la forma** de esas respuestas para la app móvil: login y signin
salen siempre como `{data:{token, user:{email, nickname}}}` y `me` como
`{user:{email, nickname}}`, aunque el backend cambie de forma por su
coordinación con web. Así, un cambio de forma allá solo se arregla en el BFF.

## 8. Flujo de fotos (`/images`)

| Petición | Uso en la app |
|---|---|
| `GET /images?categoria=&pagina=&por_pagina=` | Colección pública |
| `POST /images` (multipart, campo `file`) | Subir foto |
| `PUT /images?id=` (JSON con `motivo`) | Reportar foto |

El BFF no interpreta el contenido: reenvía método, cabeceras, query string y
**cuerpo en bytes crudos**. Ese detalle importa: si el cuerpo se pasara por
texto, el `boundary` del multipart se rompería y el backend no leería el
archivo.

El BFF **sí maquilla los errores**: cualquier 4xx/5xx con cuerpo JSON se
reduce a `{"message": "..."}` (elimina los *bread crumbs* de Ash) manteniendo
el código de estado. El cuerpo de los 2xx pasa tal cual. El contrato completo
está en `docs/conexion_backend.md`.

### La URL pública de las fotos

Cada foto se sirve desde `priv/static/uploads` de Phoenix y su `url` es
absoluta. Se construye con `PUBLIC_BASE_URL` (configurado en
`config/runtime.exs` como `:url_publica`), **no** con el host de la petición:

| Dónde corre la app | `PUBLIC_BASE_URL` |
|---|---|
| PC (browser, desktop) | `http://127.0.0.1:4001` |
| Emulador Android | `http://10.0.2.2:4001` |
| Celular físico (misma WiFi) | `http://192.168.x.x:4001` |
| **Cualquiera de los anteriores** | `http://<IP de LAN>:4001` ← el valor por defecto |

El default es la **IP de LAN** (`http://192.168.1.2:4001`) porque es la única
que funciona a la vez en el PC y en el emulador: `127.0.0.1` desde el emulador
es el propio emulador y `10.0.2.2` no existe en el PC. Si tu red tiene otra IP:

```powershell
cd backend\aves
$env:PORT = '4001'; $env:PUBLIC_BASE_URL = 'http://192.168.1.9:4001'; mix phx.server
```

> Phoenix debe escuchar en `0.0.0.0` (ya lo hace en `config/dev.exs`) o la IP de
> LAN no llega. Las fotos subidas viven en
> `_build\dev\lib\aves\priv\static\uploads` (copia de `priv/` en Windows): se
> pierden al borrar `_build`.

## Orden de arranque recomendado

1. Postgres 17 (`postgresql-x64-17`) arrancado.
2. `backend\aves`: `$env:PORT = '4001'; mix phx.server`.
3. `scripts\bff.ps1` (usa `BACKEND_URL=http://127.0.0.1:4001` por defecto).
4. `scripts\smoke-bff.ps1` → sin 502.
5. `flutter run --dart-define=BFF_ACTIVO=true` con el define que corresponda.
