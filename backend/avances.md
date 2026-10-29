# Avances Backend — Bitácora de Aves

> Resumen de la implementación realizada hasta ahora.
> **Última actualización:** 2026-10-22
> **Alcance:** backend completo (autenticación, catálogo, bitácora, colección, moderación). La sección 0 resume el estado general; las secciones 1 a 11 detallan la autenticación, roles y perfil.
> **Issues trabajados:** #9 — Registro e inicio de sesión (RF-01, RF-02) · #10 — Roles de usuario (RF-03) · #11 — Perfil de usuario (RF-04).
> La base de autenticación (bearer) de #9 la reutilizan #10 y #11.

## Contexto

- **Stack:** Elixir 1.20 / OTP 29 · Phoenix 1.8 · Ash 3 · AshAuthentication 4 · AshPostgres · PostgreSQL 16.
- **App:** `aves/` (dentro de `backend/`).
- **Contrato móvil (OpenAPI):** `../docs/modules/ROOT/attachments/openapi/birs_user_apis.yaml`.
- **Base de datos local:** `docker-compose.yaml` (raíz del repo) → servicio `db` = `postgres:16` en `localhost:5432` (usuario/clave `postgres`).

---

## Arquitectura del backend

**Idea central:** los recursos de Ash definen datos, acciones y reglas de acceso (policies) en un solo lugar. Los controllers son delgados: reciben la petición, llaman a una acción de Ash y devuelven JSON. La misma regla de permisos aplica a la API REST y al dashboard LiveView previsto.

### Arranque y configuración

- **`lib/aves/application.ex`** levanta, en orden: telemetría, `Aves.Repo`, DNSCluster, `Phoenix.PubSub`, el `Endpoint` y `AshAuthentication.Supervisor`.
- **`lib/aves/secrets.ex`** entrega `token_signing_secret` a AshAuthentication.
- **`config/config.exs`** es la base. **`dev.exs`**, **`prod.exs`** y **`test.exs`** ajustan cada entorno.
- **`config/runtime.exs`** lee variables de entorno en producción: `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT` (4000 por defecto), `DNS_CLUSTER_QUERY` y `PUBLIC_BASE_URL`.
- Variables propias: `PUBLIC_BASE_URL` (base de las URLs de fotos) y `config :aves, :uploads_dir` (carpeta de fotos, en test apunta a una carpeta temporal).

### Router y pipelines

| Scope | Pipeline | Contenido |
|---|---|---|
| `/api/json` | `:api` | Swagger UI y AshJsonApi. Sin dominios: no expone nada. |
| `/api` (públicas) | `:api` | `POST /user/signin`, `POST /user/login`, `DELETE /user/logout`. |
| `/api` (autenticadas) | `:api_auth` | Usuario, aves, categorías, avistamientos, fotos, colección y reportes. |
| `/` | `:browser` | Página Phoenix por defecto. |

El pipeline `:api_auth` incluye `AvesWeb.AuthPlug`, que lee `Authorization: Bearer <token>`, carga al usuario y lo registra como **actor** de Ash. Sin token válido responde 401.

### Autenticación

- AshAuthentication con estrategia de contraseña. Login por **email**. La contraseña se guarda como `hashed_password` (bcrypt).
- Tokens JWT **con estado**, guardados en la tabla de tokens: se pueden revocar, por eso el logout es real.
- `rol` es un átomo: `usuario` (por defecto), `moderador` o `admin`.
- `UserController` delega en las acciones de AshAuthentication. Acepta `user` como alias de `email` y `confirm_password` como alias de `password_confirmation`, por compatibilidad con el contrato inicial.

### Dominios y recursos

| Dominio | Recurso | Qué guarda | Acciones y policies clave |
|---|---|---|---|
| `Aves.Accounts` | `User` | email, nickname, `hashed_password`, rol | `assign_role` (solo admin), `update_profile` (solo el propio). Moderador lee a cualquiera y borra solo usuarios comunes. |
| `Aves.Accounts` | `Token` | Tokens emitidos y su expiración | Revocación. |
| `Aves.Catalog` | `Category` | name (único) | Lectura para cualquier autenticado; escritura para moderador y admin. |
| `Aves.Catalog` | `Bird` | name, scientific_name (único), description, category | Lectura para cualquier autenticado; escritura para moderador y admin. `has_many :photos` con avistamientos visibles. |
| `Aves.Catalog` | `BirdView` | Una fila por visita a la ficha de un ave | Base del ranking (RF-15). Se borra en cascada con el ave. |
| `Aves.Bitacora` | `Sighting` | place, spotted_on, comment, photo_url, hidden_at, deleted_at, owner, bird | `register`, `update` y `soft_delete` (dueño); `hide` (moderador); `personal_log` (RF-10); `public` (RF-11). `soft_delete` además borra el archivo de la foto. |
| `Aves.Bitacora` | `CollectionItem` | Avistamiento ajeno guardado por el usuario | Restricción única dueño + avistamiento (RF-12). |
| `Aves.Moderation` | `Report` | reason, status (`pendiente`, `aprobado`, `retirado`), reporter, sighting | Cualquiera reporta; moderador aprueba o retira. Retirar oculta el avistamiento. |

`Aves.Storage` no es un recurso: guarda y borra los archivos de las fotos (ver "Subida de fotos" en la sección 0).

### Controllers y helpers

Viven en `lib/aves_web/controllers/api/`: `UserController`, `BirdController`, `CategoryController`, `SightingController`, `PhotoController`, `CollectionController` y `ReportController`.

`helpers.ex` concentra lo común: `actor/1`, `page_opts/1` (paginación de Ash), `error_response/3` (convierte `Ash.Error.Forbidden` en 403), `sighting_json/1` (serialización con la URL completa de la foto) y `put_if/4`.

### Base de datos y migraciones

- Migraciones en `priv/repo/migrations/` (cinco en total). Snapshots de recursos en `priv/resource_snapshots/`.
- **Regla:** todo cambio de recursos se genera con `mix ash.codegen <nombre>`, nunca a mano. Si el código cambia sin codegen, el servidor de desarrollo falla al arrancar (`CheckCodegenStatus`, error 500). Las migraciones manuales dejan a Ash sin saber del esquema y provocan choques (`duplicate_table`, FKs).
- `mix ash.codegen --check` verifica que no haya cambios pendientes.

### Pruebas

- `test/support/factory.ex`: `user_with_token/1`, `category/1`, `bird/1`, `sighting/2`, `sign_in_conn/2` y `jpeg_bytes/1`.
- `mix precommit` compila con warnings como error, formatea y corre todos los tests.

### Flujo de ejemplo: `GET /api/birds/:id`

1. El endpoint y el router envían la petición a `:api_auth`.
2. `AuthPlug` valida el token y pone al usuario como actor.
3. `BirdController.show` hace `Ash.get` con el actor. La policy de lectura de `Bird` decide si puede verla.
4. Carga la categoría y hasta 50 avistamientos visibles, cada uno filtrado por las policies de `Sighting`.
5. Registra una fila en `bird_views`. Si falla, la respuesta sigue igual.
6. Responde el JSON de la ficha.

## Modelo de datos original y su estado

El enunciado pedía las entidades USUARIO, AVE, PUBLICACION, LIKE y REPORTE, con los siguientes ajustes:

| # | Ajuste pedido | Estado |
|---|---|---|
| 1 | PUBLICACION con lugar y fecha de avistamiento; `pie_de_foto` como comentario | ✅ `Sighting`: `place`, `spotted_on`, `comment`. |
| 2 | COLECCION_ITEM distinta de LIKE, con gestión desde el panel | ✅ `CollectionItem`. La gestión desde el panel la hace el equipo del dashboard. |
| 3 | AVE con descripción | ✅ `Bird.description` (y `scientific_name`). |
| 4 | REPORTE con `id_moderador`, `fecha_resolucion` y estado enum (pendiente, aceptado, rechazado) | ⚠️ Estado enum ✅, pero con valores `aprobado` y `retirado`. **No tiene** `id_moderador` ni `fecha_resolucion`. |
| 5 | USUARIO con `password_hash` y rol enum (usuario, moderador, admin) | ✅ |
| 6 | Aves populares como suma de `views_count` por ave, sin tabla extra | ⚠️ Se implementó con `bird_views` (una fila por visita) y no con un campo `views_count`. Es la decisión 1 pendiente. |

**Likes:** el modelo original los incluye (LIKE con PK compuesta). El enunciado no los menciona, y no están implementados (decisión 7).

**Contrato móvil (observaciones originales):**

| Observación | Estado |
|---|---|
| Login y registro usaban `user` | ✅ Login por email o nickname; `user` es alias (decisión 5, resuelta). |
| Typo `confirm_pasword` | ✅ `password_confirmation`, con alias `confirm_password`. |
| Reportar como `PUT /images` | ✅ `POST /api/reports`. El OpenAPI móvil todavía usa `/images` (decisión 6). |
| `POST /images` sin body | ✅ `POST /api/sightings` multipart con `photo`, `place`, `spotted_on`, `comment` y `bird_id`. |
| `GET /images` solo con URLs | ✅ `GET /api/photos`, paginado y con datos del avistamiento. |
| Login debe devolver el token | ✅ |
| Faltaban buscador, populares, likes y colección | ✅ Excepto likes (decisión 7). |

**Comunicación:** la app móvil usa REST con bearer token. El dashboard LiveView se conectará al mismo backend, reutilizando las acciones de Ash (login por sesión, pendiente).

## Historial de la sesión del 22-oct

Este bloque reemplaza a `sesion_20261022.md`, que se eliminó porque su contenido ya está en las secciones de arriba. Lo que se conserva aquí es lo que no está en otro lugar.

- **Merges de la rama:** `jose` (PR #28, accounts), `mauricio` (RF-08 a RF-14, sightings y moderación) y `marcelo` (catálogo). El merge de `marcelo` se publicó con marcadores de conflicto (`<<<<<<< HEAD`) dentro del código. Los commits siguientes solo borraron las líneas de marcador y dejaron `category.ex` roto. Se corrigió en esa sesión.
- **Correcciones de compilación:** `require Ash.Query` en `bird_controller.ex`, cláusulas `{:error, ...}` redundantes y un alias sin uso (todo con `warnings-as-errors`).
- **Bug de updates atómicos:** la policy con `expr(actor.rol in [...])` falla en updates atómicos con `Invalid reference actor.rol`. La forma correcta es `expr(^actor(:rol) in [...])`.
- **Errores de permiso:** `error_response/3` devuelve 403 para `Ash.Error.Forbidden`, sin importar el estado que pida el controller.
- **Comandos útiles:** están en `backend/readme.md`.

---

## Métricas y estadísticas (2026-10-29)

Implementadas las golden signals con Prometheus y las estadísticas de admin por WebSocket. La vista (dashboard de Grafana y frontend) no es responsabilidad del backend, salvo la conexión de datos.

### Golden signals

- **Librería:** PromEx 1.12 (`Aves.PromEx`), aprobada. Sus plugins de Phoenix, Ecto, Beam y Application publican las métricas. El servidor HTTP de PromEx está desactivado; el endpoint vive en la app.
- **Endpoint:** `GET /metrics`, en formato Prometheus, protegido con basic auth (`AvesWeb.MetricsAuth`). Las credenciales vienen de `config :aves, :metrics_auth`: `METRICS_USER` y `METRICS_PASSWORD` en producción; en desarrollo, `prometheus`/`prometheus`.

| Señal | Métrica (prefijo `aves_prom_ex_`) |
|---|---|
| Latencia | `phoenix_http_request_duration_milliseconds` (histograma, por ruta y estado) |
| Tráfico | `phoenix_http_requests_total` (por ruta, método y estado) |
| Errores | la misma métrica, filtrando `status="5xx"` |
| Saturación (VM) | `beam_stats_run_queue_count`, `beam_memory_*_bytes` |
| Saturación (base de datos) | `ecto_repo_query_queue_time_milliseconds` (espera del pool de conexiones) |
| Saturación (disco) | `aves_uploads_free_bytes` (espacio libre donde viven las fotos) |

### Estadísticas de admin

- **Módulo:** `Aves.Stats.snapshot/0` cuenta usuarios por rol, aves, avistamientos por estado (visible, oculto, eliminado), reportes por estado, colecciones, vistas, el top de 10 aves populares y el espacio libre del disco.
- **Canal:** WebSocket `stats:admin` (`AvesWeb.StatsChannel`), conectado por `/socket/websocket`. El token es el mismo bearer que la API; `AvesWeb.UserSocket` lo valida con el mismo código que `AuthPlug`.
  - Solo entra el rol `admin`. Un moderador o un usuario común recibe `{reason: "forbidden"}`.
  - Al unirse, el servidor empuja un evento `snapshot`. Después empuja uno nuevo cada 30 segundos.
  - El evento `refresh` pide un snapshot inmediato.
- **Prometheus:** `Aves.PromEx.StatsPlugin` publica los mismos conteos como gauges (`aves_users_count{rol=…}`, `aves_sightings_count{state=…}`, `aves_reports_count{status=…}`, `aves_birds_count`, `aves_collection_items_count`, `aves_bird_views_count`, `aves_uploads_free_bytes`). Se actualizan cada 30 segundos.

### Infraestructura local

- `docker-compose.yaml` agrega **Prometheus** (puerto 9090) y **Grafana** (puerto 3000, usuario `admin`, contraseña `admin`).
- `observability/prometheus/prometheus.yml` raspa `host.docker.internal:4000/metrics` con las credenciales de desarrollo.
- `observability/grafana/provisioning/datasources/` define la fuente de datos Prometheus. Los dashboards viven solo en Grafana, no en el repo (decisión tomada).
- Verificado: el target de Prometheus está `up`, los gauges de negocio llegan (`aves_users_count` con sus tres roles) y Grafana responde con la fuente de datos cargada.

### Verificación

- `mix precommit`: **110 tests** (7 nuevos del módulo de estadísticas, el canal y `/metrics`).
- WebSocket real (cliente Node sobre el servidor de desarrollo): el admin recibe `snapshot`; el usuario común recibe `forbidden`; un token inválido no conecta.
- `/metrics` sin credenciales responde 401, con credenciales correctas responde 200.
- Advertencia conocida: en los tests del canal aparecen `Dropping aggregation for bad tag value … tag: :transport`. Viene de la metadata que simula `Phoenix.ChannelTest`; con el servidor real no aparece.

### Decisiones tomadas

- Estadísticas de admin por WebSocket, no por REST.
- Dashboards de Grafana: solo en Grafana, sin JSON versionado en el repo.

---

## 0. Estado general del backend (2026-10-22)

**Rama:** `fix/backend/correccion_detalles`. Incluye el trabajo de jose, mauricio y marcelo, y las correcciones de la sesión del 22-oct (ver "Historial de la sesión del 22-oct").

### Cobertura de requisitos

| RF | Requisito | Estado | Dónde |
|---|---|---|---|
| RF-01..04 | Registro, sesión, roles, perfil | ✅ | §1–§6 |
| RF-05 | CRUD de aves | ✅ | `Aves.Catalog.Bird`, `BirdController` |
| RF-06 | Buscador por nombre y categoría | ✅ | `GET /api/birds?name=&category_id=` |
| RF-07 | Ficha de ave | ✅ | `GET /api/birds/:id` (categoría, nombre científico, descripción, galería de hasta 50 avistamientos) |
| RF-08..10 | Avistamientos: registrar, editar, eliminar, bitácora | ✅ | `SightingController` |
| RF-11 | Fotos de otros usuarios con filtros | ✅ | `PhotoController` |
| RF-12 | Colección personal | ✅ | `CollectionController` |
| RF-13 | Reportar foto | ✅ | `POST /api/reports` |
| RF-14 | Cola de moderadores (aprobar / retirar) | ✅ | `POST /api/reports/:id/approve` y `/retire` |
| RF-15 | Aves populares | ✅ | `GET /api/birds/ranking` ordena por `views_count`, contado desde `bird_views` (una fila por cada `GET /api/birds/:id`) |
| RF-16 | Gestión de usuarios desde admin (ver, editar, suspender) | 🔵 | Decisión: esta gestión se expone solo por WebSockets, no por REST. Sin endpoints REST. Las acciones `assign_role` y `destroy` ya existen con sus policies. |
| RF-17 | Dashboard de aves y colecciones | 🔵 | Fuera de la responsabilidad del backend (la capa LiveView la hace otro equipo). |
| RF-18 | Landing | 🔵 | Fuera del backend (`landing/`) |
| RF-19 | OpenAPI completo | ⚠️ | Usuarios en `birs_user_apis.yaml`; resto del backend en `birs_apis.yaml` (`docs/modules/ROOT/attachments/openapi/`). Falta el contrato de `/images` (decisión 6) |
| RF-20 | Colección Bruno | ✅ | `backend/bruno/`: 33 requests que cubren todos los endpoints. Pasan 33/33 en dos corridas seguidas contra el servidor de desarrollo (ver `backend/bruno/README.md`) |

### Endpoints REST (`/api`)

- **Públicos:** `POST /user/signin`, `POST /user/login`, `DELETE /user/logout`.
- **Autenticados (bearer):**
  - Usuario: `GET|PATCH /user/me`.
  - Aves: `GET /birds`, `GET /birds/ranking`, `GET /birds/:id`, y `POST|PATCH|DELETE` (moderador o admin para escribir).
  - Categorías: `GET|POST|PATCH|DELETE /categories`.
  - Avistamientos: `GET|POST /sightings`, `PATCH|DELETE /sightings/:id`.
  - Fotos: `GET /photos`.
  - Colección: `GET|POST /collection`, `DELETE /collection/:id`.
  - Reportes: `GET|POST /reports`, `POST /reports/:id/approve`, `POST /reports/:id/retire`.
- **Otros:** `/api/json/*` (AshJsonApi) y Swagger UI en `/api/json/swaggerui`.

### Subida de fotos (2026-10-22)

**Archivos:** `lib/aves/storage.ex` (nuevo), `lib/aves_web/controllers/api/sighting_controller.ex`, `lib/aves_web.ex`, `config/test.exs`.

- `POST /api/sightings` y `PATCH /api/sightings/:id` aceptan el campo multipart `photo`. Si se envía, la foto reemplaza a `photo_url`.
- `Aves.Storage.store/1` valida la foto, la copia a una carpeta pública y devuelve la URL que se guarda en la base de datos:
  - **Carpeta:** `priv/static/uploads`, servida en `/uploads`. Configurable con `config :aves, :uploads_dir`.
  - **Nombre:** UUID aleatorio más la extensión detectada. Dos fotos nunca comparten nombre.
  - **URL guardada:** ruta relativa, por ejemplo `/uploads/aafe295e-0c10-439b-a0ba-29b9a552735b.jpg`.
  - **Formatos:** JPEG y PNG, según el tipo real del archivo (sus primeros bytes), no según el nombre ni el `Content-Type` del cliente. Coincide con la validación de `photo_url`.
  - **Tamaño:** máximo 5 MB.
  - **Metadatos:** antes de guardar se quitan los datos EXIF (incluido el GPS de la cámara), XMP, comentarios y chunks de texto de PNG. En JPEG se conservan APP0 (JFIF) y APP2 (perfil de color). Un JPEG con la estructura rota se rechaza con 422. Verificado con un JPEG real de `sips`: se quitaron APP1 (EXIF) y APP13 (IPTC) y el resto quedó igual.
- Los tests escriben en una carpeta temporal. `.gitignore` excluye `priv/static/uploads/`.
- **Verificación:** `mix precommit` con 93 tests (los de subida, limpieza, borrado y metadatos). Prueba manual con `curl` contra el servidor de desarrollo: la foto se guardó, la URL devuelta respondió `200 image/jpeg` y el nombre quedó en `photo_url`.
- **Limitaciones:**
  - **Resuelto:** si la base de datos rechaza el alta o el `PATCH`, la foto recién subida se borra. Si un `PATCH` con foto nueva tiene éxito, se borra la anterior.
  - **Resuelto:** al eliminar un avistamiento (`soft_delete`) se borra su archivo, después de confirmar la transacción (`Aves.Bitacora.Changes.RemovePhotoFile`). La fila sigue en la base con su `photo_url`, oculta por `deleted_at` y sin archivo.
  - **Moderación:** retirar una foto (`hide`) no borra el archivo, para poder restaurarla.
  - **Resuelto:** la base de datos guarda la ruta relativa, pero las respuestas de la API devuelven la URL completa. `Helpers.public_photo_url/1` antepone `config :aves, :public_base_url` (por defecto `http://127.0.0.1:4000` en desarrollo y `https://<PHX_HOST>` en producción). La variable `PUBLIC_BASE_URL` la sobrescribe, por ejemplo con `http://10.0.2.2:4000` para el emulador de Android.
  - En un despliegue con contenedores, los archivos se pierden al redesplegar si no hay volumen persistente.

### Migraciones

| Versión | Nombre | Contenido |
|---|---|---|
| 20261007194006 | `initialize_and_add_authentication_resources_extensions_1` | Extensiones (citext) |
| 20261007194007 | `initialize_and_add_authentication_resources` | Usuarios y tokens |
| 20261009122556 | `add_user_auth_fields` | Campos de autenticación de usuario |
| 20261015223749 | `initial_catalog_bitacora_moderation` | Categorías, aves, avistamientos, colección, reportes |
| 20261022015932 | `add_bird_views_and_details` | `bird_views`; `scientific_name` y `description` en `birds` (RF-07) |
| 20261022035822 | `add_bird_views_cascade_and_index` | Índice sobre `bird_views.bird_id`; FK con `ON DELETE CASCADE` |

- La migración `20261021230001_add_bird_views` fue **reemplazada** por `20261022015932`. El commit que la contiene (`480049e`) existe solo en local y no está en el remoto. En la base local `aves_dev` solo está aplicada la nueva. Si algún integrante ya aplicó la vieja, su `bird_views` tendrá índice y la migración nueva fallará con `duplicate_table`; hay que coordinarlo antes de subir.
- Toda migración de recursos se genera con `mix ash.codegen <nombre>`. `mix ash.codegen --check` pasa sin cambios pendientes.

### Verificación (2026-10-22)

- `mix precommit` → compilación sin warnings, formato y **78 tests pasan** (71 previos + 7 de `bird_controller_test.exs`: filtro, UUID inválido, ficha con galería, registro de vista, 404, ranking por vistas, borrado en cascada).
- `mix ash.codegen --check` sin cambios pendientes.
- Pruebas manuales de la sesión (curl): `PATCH` de admin con `scientific_name` y `description` → OK; `PATCH` de usuario normal → 403; `GET /api/birds/:id` devuelve la ficha con galería.

### Correcciones del 22-oct y pendientes

1. **Resuelto:** `bird_views` tiene índice sobre `bird_id` (migración `20261022035822`).
2. **Resuelto:** la FK tiene `ON DELETE CASCADE`. Borrar un ave elimina sus vistas. Los avistamientos siguen bloqueando el borrado con 422 (regla de negocio, con mensaje de Ash).
3. **Resuelto:** `category_id` inválido responde 422 con mensaje claro. Los errores de lectura y del ranking ya no salen como 403 por defecto.
4. **Resuelto:** `show` responde 500 controlado si `Ash.load` falla, en vez de lanzar `WithClauseError`.
5. **Documentación desactualizada en el código.** Los `@moduledoc` de `Aves.Catalog` y `Aves.Catalog.Bird` dicen que el CRUD de aves está en otro issue, y ya no es así.
6. **Resuelto (decisión del equipo):** RF-15 cuenta `bird_views`. El ranking anterior nunca sumaba bien porque el SQL devolvía el UUID como binario y no coincidía con el `id` del ave; ahora se castea a texto. El campo de respuesta pasó de `sightings_count` a `views_count`. No había consumidores de ese campo.

### Divergencias con el modelo original

- El modelo original define PUBLICACION, LIKE y `views_count`, y prohíbe una tabla extra para populares. La implementación usa **`Sighting`** como publicación y creó **`bird_views`**. El `requisitos.adoc` no menciona likes. Hay que validarlo con el equipo (ver "Modelo de datos original y su estado").

### Pendientes por realizar (2026-10-22)

- **RF-19, OpenAPI completo:** falta documentar `/images` (los stubs de `birs_user_apis.yaml`), que depende de la decisión 6. Los endpoints del backend ya están en `birs_apis.yaml`.
- **Almacenamiento en producción:** la subida de fotos ya funciona en disco local (ver sección 0, "Subida de fotos"). Falta resolver dónde guardarlas en Fly.io, porque su disco es efímero (decisión 8).
- **Despliegue:** GitHub Actions y Fly.io, según el enunciado. Todavía no hay configuración en el repo.
- **Limpieza:**
  - Quitar o usar el router de AshJsonApi, que está vacío.
  - Mover `secret_key_base` y `token_signing_secret` de `config/dev.exs` a variables de entorno.
  - Corregir `db/seeds.exs`: no es idempotente, aunque su encabezado dice que sí. Al volver a correrlo falla con `usuario@aves.test` ya existente.
- **Prueba con foto real de teléfono:** la limpieza de EXIF solo está probada con JPEG sintéticos y uno de `sips`.
- **Commit:** el trabajo del 22-oct y de los días siguientes está sin commitear. Incluye `backend/bruno/`, `birs_apis.yaml`, `storage.ex` y los cambios de config. El commit `480049e` existe solo en local.
- **Documentación de Antora:** el enunciado la pide; no se ha revisado en este documento.

### Pendientes por decidir (2026-10-22)

1. **Resuelto: vistas del ranking (RF-15):** cada visita cuenta, sin deduplicar por usuario. Las búsquedas y listados no suman; solo la ficha (`GET /api/birds/:id`) registra una vista, como está implementado.
2. **Resuelto: borrar ave con avistamientos:** se mantiene la respuesta 422. Los avistamientos bloquean el borrado.
3. **Pendiente: borrado de categorías con aves:** la FK no tiene `on_delete`. No está probado qué responde hoy.
4. **Resuelto: estados del reporte:** se mantienen los valores del código: `pendiente`, `aprobado` y `retirado`. El modelo original (`aceptado` y `rechazado`) no se sigue.
5. **Resuelto: login por nickname:** `POST /api/user/login` acepta email o nickname, en `email` o en el alias `user`. Si el valor no tiene `@`, se busca el usuario por nickname y se autentica con su email. Un nickname inexistente responde 401.
6. **Contrato móvil:** el OpenAPI de móvil usa `/images` y `PUT /images` para reportar. El backend expone `/api/photos` y `/api/reports`. Hay que decidir cuál se mantiene y avisar al equipo.
7. **Likes:** el modelo original los incluye y el enunciado no. Hay que decidir si se implementan.
8. **Almacenamiento de fotos:** en desarrollo ya se guarda en disco local (`priv/static/uploads`). Falta decidir el destino en producción: volumen de Fly.io, S3 u otro proveedor.
9. **URL base para el móvil:** ¿se mantiene `PUBLIC_BASE_URL` con la configuración del servidor? Para un teléfono físico hay que decidir si el servidor de desarrollo escucha en `0.0.0.0`.

---

## 1. Recurso de usuario (autenticación)

**Archivo:** `aves/lib/aves/accounts/user.ex`

- Estrategia `password` de **AshAuthentication**:
  - login por **`email`** (`identity_field :email`),
  - hash en **`hashed_password`** (`hashed_password_field`),
  - el registro acepta `nickname` (`register_action_accept [:nickname]`).
- Atributos:
  | Atributo | Tipo | Notas |
  |---|---|---|
  | `id` | `uuid` (PK) | generado por `gen_random_uuid()` |
  | `email` | `ci_string` (citext) | único, case-insensitive |
  | `nickname` | `string` | único |
  | `hashed_password` | `string` | `sensitive? true` (bcrypt) |
  | `rol` | `atom` | enum `usuario`/`moderador`/`admin`, default `usuario` |
  | `inserted_at` / `updated_at` | timestamps | |
- Identidades únicas: `unique_email`, `unique_nickname`.
- **Tokens stateful y revocables**: `store_all_tokens? true` + `require_token_presence_for_authentication? true`.
- Add-on `log_out_everywhere` (revoca todo al cambiar contraseña).

**Migración:** `aves/priv/repo/migrations/20261009122556_add_user_auth_fields.exs`
(agrega columnas, índices únicos y usa la extensión `citext`).

---

## 2. Endpoints REST para el cliente móvil

**Controlador:** `aves/lib/aves_web/controllers/api/user_controller.ex`
**Router:** `aves/lib/aves_web/router.ex`

| Método | Ruta | Acción | Respuesta |
|---|---|---|---|
| `POST` | `/api/user/signin` | registro | `201` `{user, token}` · `422` en datos inválidos |
| `POST` | `/api/user/login` | inicio de sesión | `200` `{user, token}` · `401` credenciales inválidas |
| `DELETE` | `/api/user/logout` | cierre de sesión | `204` (revoca el bearer) |
| `GET` | `/api/user/me` | perfil autenticado | `200` `{user}` · `401` sin token |
| `PATCH` | `/api/user/me` | editar perfil (ver §6) | `200` `{user}` · `401` · `422` |

- El controlador **no reimplementa auth**: delega en `AshAuthentication.Strategy.action/3`
  (`:register`, `:sign_in`), por lo que las mismas acciones sirven para el futuro dashboard web.
- Compatibilidad con el contrato inicial: acepta `user` como alias de `email` y
  `confirm_password` como alias de `password_confirmation`.

**Contrato:**
```jsonc
// POST /api/user/signin
{ "email": "...", "nickname": "...", "password": "...", "password_confirmation": "..." }

// POST /api/user/login
{ "email": "...", "password": "..." }

// Respuesta de ambos
{ "user": { "id": "...", "email": "...", "nickname": "...", "rol": "usuario" },
  "token": "eyJhbGciOi..." }   // bearer JWT
```

---

## 3. Bearer token / autenticación de peticiones

**Archivo:** `aves/lib/aves_web/auth_plug.ex`

Module plug (`init/1` + `call/2`) que:
1. verifica el header `Authorization: Bearer <token>`,
2. carga al usuario,
3. lo establece como **actor de Ash** (`Ash.PlugHelpers.set_actor`) para que apliquen las policies,
4. responde `401` si el token falta o es inválido.

**Pipeline** `:api_auth` en el router (`plug AvesWeb.AuthPlug`). Es la base para los endpoints
protegidos de #11, #14, etc.

> Variante sin exigir token: `plug AvesWeb.AuthPlug, require: false`.

---

## 4. Contrato OpenAPI actualizado

**Archivo:** `../docs/modules/ROOT/attachments/openapi/birs_user_apis.yaml` (versión `1.1.0`)

- Rutas de users movidas a `/api/user/...` + logout + me.
- Bodies corregidos (`email`, `nickname`, `password_confirmation`), respuestas con `{user, token}`.
- Schemas: `User`, `AuthResponse`, `RegisterRequest`, `LoginRequest`, `Error`.
- Esquema de seguridad unificado: `bearerAuth` (JWT).
- Servers con puerto: `http://127.0.0.1:4000`.

> Pendiente (otros issues): el contenido de `/images` (body, respuestas, reportar, buscador, populares).

---

## 5. Roles y políticas de acceso (RF-03 / issue #10)

**Archivo:** `aves/lib/aves/accounts/user.ex`

El recurso `User` usa `Ash.Policy.Authorizer`. Cada petición autenticada lleva el
usuario como **actor** (ver §3) y las policies deciden según su `rol`.

| Rol | Puede |
|---|---|
| Invitado (sin actor) | Ver contenido público (fuera del recurso `User`) |
| `usuario` | Leer **su propio** perfil |
| `moderador` | Leer cualquier usuario · eliminar usuarios con rol `usuario` |
| `admin` | Acceso total (incluye asignar roles) |

Policies implementadas:

```elixir
policies do
  bypass AshAuthentication.Checks.AshAuthenticationInteraction do
    authorize_if always()
  end

  # admin: acceso total
  policy actor_attribute_equals(:rol, :admin) do
    authorize_if always()
  end

  # cada usuario: leer su propio perfil
  policy [action_type(:read), expr(id == ^actor(:id))] do
    authorize_if always()
  end

  # moderador: leer cualquier usuario
  policy [actor_attribute_equals(:rol, :moderador), action_type(:read)] do
    authorize_if always()
  end

  # moderador: eliminar solo usuarios comunes
  policy [
    actor_attribute_equals(:rol, :moderador),
    action_type(:destroy),
    expr(rol == :usuario)
  ] do
    authorize_if always()
  end
end
```

- Se agregan las acciones por defecto `:read` y `:destroy`.
- Nueva acción `update :assign_role` (acepta `:rol`): solo la autoriza la policy de admin.

### Bootstrap del primer admin

Ninguna policy permite crear un admin cuando aún no existe ninguno, por lo que el
alta se hace con un bypass controlado:

- `Aves.Accounts.create_admin/1` (`aves/lib/aves/accounts.ex`): registra el usuario
  con la estrategia `:password` (hashea la contraseña) y luego le asigna `rol: :admin`
  con `authorize?: false`; si el email ya existe, solo lo promueve.
- Task: **`mix aves.create_admin EMAIL NICKNAME PASSWORD`**
  (`aves/lib/mix/tasks/aves.create_admin.ex`).

---

## 6. Perfil de usuario (RF-04 / issue #11)

**Archivos:** `aves/lib/aves/accounts/user.ex`,
`aves/lib/aves_web/controllers/api/user_controller.ex`, `aves/lib/aves_web/router.ex`

- **Ver** el perfil: `GET /api/user/me` (ya existente desde #9).
- **Editar** el perfil: `PATCH /api/user/me`, que actualiza `nickname` y/o `email`
  de forma parcial. El resto de campos (`rol`, `password`, …) se ignora aunque el
  cliente los envíe.

Acción nueva:

```elixir
update :update_profile do
  description "Actualiza el perfil del propio usuario (nickname/email)."
  accept [:nickname, :email]
  require_atomic? false
end
```

Policy nueva (se limita por **nombre de acción**, no por `action_type(:update)`,
para que un usuario no pueda invocarse `:assign_role` y auto-promoverse):

```elixir
policy [action(:update_profile), expr(id == ^actor(:id))] do
  authorize_if always()
end
```

**Contrato:**
```jsonc
// PATCH /api/user/me   (Authorization: Bearer <token>)
{ "nickname": "ana_nueva", "email": "ana@nuevo.com" }   // parcial, cualquiera de los dos

// 200
{ "user": { "id": "...", "email": "...", "nickname": "...", "rol": "usuario" } }
```

> La unicidad de `email`/`nickname` la garantizan las identidades del recurso →
> `422` si ya están en uso.

---

## 7. Archivos involucrados

```
backend/
├── avances.md                                  ← este documento
└── aves/
    ├── lib/aves/accounts.ex                    (modificado — create_admin/1)
    ├── lib/aves/accounts/user.ex               (modificado — roles, policies y update_profile)
    ├── lib/aves_web/auth_plug.ex               (nuevo en #9)
    ├── lib/aves_web/controllers/api/user_controller.ex   (nuevo en #9; update_me en #11)
    ├── lib/aves_web/router.ex                  (modificado en #9; ruta PATCH en #11)
    ├── lib/mix/tasks/aves.create_admin.ex      (nuevo en #10)
    ├── test/aves/accounts/user_policies_test.exs          (nuevo en #10; +update_profile en #11)
    ├── test/aves_web/controllers/api/user_controller_test.exs (nuevo en #9; +PATCH en #11)
    └── priv/repo/migrations/20261009122556_add_user_auth_fields.exs (nuevo en #9)
```

---

## 8. Verificación realizada

- `mix precommit` → **40 tests pasan** (15 de autenticación de #9 + 15 de roles de #10 + 10 de perfil de #11).
- **Matriz de roles** cubierta por tests (`Ash.can?`): usuario no puede asignar roles ni
  eliminar; moderador elimina solo a `usuario` (no a otros moderadores ni admins);
  admin puede todo; invitado sin acceso.
- **Perfil (#11)** cubierto por tests: el usuario actualiza su `nickname`/`email`,
  no puede editar el perfil de otro, un `usuario` no puede auto-invocar `assign_role`,
  y se ignora el intento de cambiar `rol` por el body (`422` en duplicados).
- **Prueba HTTP real** (servidor levantado + curl), ciclo completo del token:

  | Paso | Resultado |
  |---|---|
  | Registro → token | ✅ |
  | `GET /api/user/me` con token | `200` + usuario |
  | `GET /api/user/me` sin token | `401` |
  | `DELETE /api/user/logout` | `204` |
  | `GET /api/user/me` con token revocado | `401` (revocación real) |

- **Bootstrap admin probado** con `mix aves.create_admin`: crea un admin nuevo y
  promueve uno existente.

---

## 9. Cómo levantar el backend

```bash
# 1. Base de datos (desde la raíz del repo)
docker compose up -d db

# 2. Migraciones y servidor (desde backend/aves)
mix deps.get
mix ecto.create && mix ash.migrate
mix phx.server

# 3. (opcional) Crear el primer administrador
mix aves.create_admin admin@example.com admin una-clave-segura
```

---

## 10. Decisiones de diseño

- **PK UUID** en todo el modelo (consistencia con el scaffold; IDs no adivinables en la API pública).
- **Login por `email` o `nickname`**: AshAuthentication autentica por email; el controller resuelve el nickname a su email antes de llamar a la estrategia. Decisión 5 de la lista de pendientes.
- **Tokens stateful/revocables** (permiten logout real y `log_out_everywhere`), a costa de una consulta a BD por request.
- **Prefijo `/api`** para los endpoints REST.
- **Opción A** para exponer auth: controlador Phoenix (control explícito del token en la respuesta) en lugar de rutas de AshJsonApi.
- **Autorización por roles con policies de Ash** (no en el controlador): el rol se evalúa con `actor_attribute_equals/2` y `expr(...)`, de modo que las mismas reglas valen para REST y para el dashboard LiveView.
- **Bypass controlado para el bootstrap**: `create_admin` usa `authorize?: false` porque ninguna policy puede autorizar la creación del primer admin.
- **Perfil editable = `nickname` + `email`** vía `PATCH /api/user/me`; la contraseña y el rol no se editan por aquí. La policy se limita por **nombre de acción** (`action(:update_profile)`) para no habilitar `:assign_role` a un usuario común.

---

## 11. Pendientes / siguientes pasos

- **Endpoints/dashboard de administración:** listar usuarios, asignar rol (`assign_role`) y eliminar usuarios desde REST/LiveView, reutilizando las acciones y policies ya definidas.
- **Permisos de publicaciones/colecciones/reportes:** aplicar el mismo patrón de roles cuando existan esos recursos (#13/#14).
- **Login del dashboard web:** por sesión en LiveView (no bearer), reutilizando las mismas acciones.
- **Contrato `/images`:** actualizar body/respuestas y `POST /reportes` en sus issues (#13/#14).
- **Métricas (admin):** "acceso a métricas de datos" queda para la feature de métricas.
- **Cambio de contraseña:** si se requiere, exponerlo como flujo aparte (acción de AshAuthentication).
