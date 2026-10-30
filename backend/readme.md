# Backend de Aves: cómo levantarlo y probarlo

Backend en Elixir, Phoenix, Ash y PostgreSQL. El contexto del proyecto (arquitectura, modelo de datos, estado de los requisitos y pendientes) está en [`avances.md`](avances.md).

## Requisitos

- **Docker Desktop**, con el motor encendido. Si no está activo, la base de datos no arranca y los comandos de Mix fallan con `connection refused` en el puerto 5432.
- **Elixir 1.20 y OTP 29.**
- **Node.js y npm**, solo para correr la colección de Bruno por línea de comandos.

## 1. Base de datos

Desde la raíz del repositorio (`2026_ProyectoAves/`):

```bash
docker compose up -d db
```

Verificar que esté lista:

```bash
docker exec 2026_proyectoaves-db-1 pg_isready -U postgres
```

Debe responder `accepting connections`. PostgreSQL 16 queda en `localhost:5432`, usuario y contraseña `postgres`.

## 2. Dependencias y esquema

Desde `backend/aves/`:

```bash
mix deps.get
mix ecto.create
mix ash.migrate
```

`mix ecto.create` solo hace falta la primera vez. Para confirmar que el esquema está al día:

```bash
mix ash.codegen --check
```

Debe terminar sin cambios pendientes.

## 3. Datos de prueba (seeds)

```bash
mix run priv/repo/seeds.exs
```

Crea tres usuarios, todos con contraseña `supersecret123`:

| Email | Rol |
|---|---|
| `usuario@aves.test` | usuario |
| `moderador@aves.test` | moderador |
| `admin@aves.test` | admin |

Además crea categorías, aves y avistamientos.

> **Importante:** los seeds **no son idempotentes**, aunque su encabezado diga lo contrario. Correrlos una segunda vez falla con `has already been taken`. Si ya los corriste, no hace falta volver a correrlos.

Si necesitas un administrador adicional:

```bash
mix aves.create_admin EMAIL NICKNAME PASSWORD
```

## 4. Servidor

Desde `backend/aves/`:

```bash
mix phx.server
```

Queda en `http://127.0.0.1:4000`. Para comprobarlo:

```bash
curl -s -X POST http://127.0.0.1:4000/api/user/login \
  -H 'content-type: application/json' \
  -d '{"email":"usuario@aves.test","password":"supersecret123"}'
```

Debe responder un JSON con `user` y `token`.

**Emulador de Android:** la URL que el backend escribe en `photo_url` debe ser alcanzable desde el emulador. Arranca el servidor con:

```bash
PUBLIC_BASE_URL=http://10.0.2.2:4000 mix phx.server
```

`10.0.2.2` es el `localhost` de la computadora visto desde el emulador.

## 5. Pruebas con Bruno

La colección está en `backend/bruno/`, con 33 requests que cubren todos los endpoints implementados. Detalle de cada carpeta y variable en [`bruno/README.md`](bruno/README.md).

### Opción A: app de Bruno

1. Abrir la carpeta `backend/bruno` en Bruno.
2. Elegir el entorno **Local**.
3. Ejecutar la colección completa desde la raíz.

### Opción B: línea de comandos

```bash
cd backend/bruno
npx -y @usebruno/cli@2 run -r --env Local
```

El resultado esperado es `33/33` requests pasando. La colección se puede correr varias veces seguidas: cada corrida crea sus propios datos.

Notas sobre el resultado:

- `Registrar usuario` acepta 422 porque `nuevo@aves.test` ya existe después de la primera corrida.
- `Cerrar sesion` revoca el token de `usuario`. Va en la última carpeta, así que no afecta al resto.
- `Registrar avistamiento con foto` sube `fixtures/ave.png`. Para probar con otra foto, cambia la ruta en la request.
- `Eliminar ave` y `Eliminar categoria` responden 422 si el registro tiene datos asociados. La colección solo borra los que ella misma crea.

## 6. Pruebas automáticas

```bash
cd backend/aves
mix precommit
```

Compila con warnings como error, formatea y corre todos los tests. Necesita la base de datos encendida.

## 7. Métricas y estadísticas de admin

### Métricas (golden signals)

Con el servidor corriendo, desde la raíz del repositorio:

```bash
docker compose up -d prometheus grafana
```

- Métricas crudas: `curl -u prometheus:prometheus http://127.0.0.1:4000/metrics` (sin credenciales responde 401).
- Prometheus: `http://localhost:9090`. En **Status → Targets** el target `aves_backend` debe estar `UP`.
- Grafana: `http://localhost:3000`, usuario `admin`, contraseña `admin`. La fuente de datos Prometheus ya está creada; los dashboards todavía no.

Si el target aparece `DOWN`, revisa que el backend esté en el puerto 4000 y que las credenciales de `observability/prometheus/prometheus.yml` coincidan con `METRICS_USER` y `METRICS_PASSWORD`.

### Estadísticas de admin por WebSocket

Solo un usuario con rol `admin` puede unirse. El canal es `stats:admin`, conectado a:

```
ws://127.0.0.1:4000/socket/websocket?token=<token del admin>&vsn=2.0.0
```

El protocolo es el de Phoenix (vsn 2.0.0), con mensajes JSON de la forma `[join_ref, ref, topic, event, payload]`:

```json
["1", "1", "stats:admin", "phx_join", {}]
```

- Al unirse, el servidor responde `phx_reply` (`status: "ok"`) y empuja un evento `snapshot` con los números.
- Cada 30 segundos llega otro `snapshot`.
- Para pedir uno inmediato, envía `["1", "2", "stats:admin", "refresh", {}]`.
- Un usuario sin rol admin recibe `phx_reply` con `status: "error"` y `reason: "forbidden"`.

Un ejemplo de `snapshot`:

```json
{
  "users": {"usuario": 5, "moderador": 1, "admin": 1},
  "birds": 3,
  "sightings": {"visible": 19, "hidden": 9, "deleted": 14},
  "reports": {"retirado": 9},
  "collection_items": 1,
  "bird_views": 15,
  "popular_birds": [{"id": "…", "name": "Flamenco chileno", "views": 9}],
  "uploads_free_bytes": 45852413952,
  "generated_at": "2026-10-29T18:00:00Z"
}
```

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `connection refused` en el puerto 5432 | Docker no está encendido o el contenedor no corre | Abrir Docker Desktop y ejecutar `docker compose up -d db` |
| `Pending Code Generation Detected` | Cambiaste un recurso Ash sin generar la migración | `mix ash.codegen <nombre>` y después `mix ash.migrate` |
| El servidor responde 500 al arrancar | Mismo motivo que el anterior: `CheckCodegenStatus` | Igual que el anterior |
| `has already been taken` al correr seeds | Los seeds ya se corrieron | No vuelvas a correrlos |
| Bruno dice `Requests: 0` | Falta `-r` en el comando | Usar `run -r --env Local` |
| Bruno responde 401 en requests de avistamientos, colección o reportes | Esas requests usan `userToken`, que solo llena `Login usuario`, y no se ejecutó | Ejecutar `Login usuario` antes, o la colección completa |
| Bruno responde 401 en perfil, ranking o búsquedas después de iniciar sesión como admin o moderador | Ya no pasaba: estas requests usan la última sesión iniciada (`token`) | Si aún ocurre, revisar que el login se haya ejecutado con el entorno `Local` |
| `ENOENT` en `Registrar avistamiento con foto` | La ruta del archivo no existe | Revisar `fixtures/ave.png` o la ruta en la request |
| Puerto 4000 ocupado | Otro servidor de Phoenix sigue corriendo | `pkill -f phx.server` y volver a levantarlo |
