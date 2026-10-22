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

## 0. Estado general del backend (2026-10-22)

**Rama:** `fix/backend/correccion_detalles`. Incluye el trabajo de jose, mauricio y marcelo, y las correcciones de la sesión del 22-oct (detalle en `sesion_20261022.md`).

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
| RF-16 | Gestión de usuarios desde admin (ver, editar, suspender) | ❌ | Sin endpoints |
| RF-17 | Dashboard de aves y colecciones | ⚠️ parcial | Solo API; falta la capa LiveView |
| RF-18 | Landing | 🔵 | Fuera del backend (`landing/`) |
| RF-19 | OpenAPI completo | ⚠️ | Usuarios en `birs_user_apis.yaml`; resto del backend en `birs_apis.yaml` (`docs/modules/ROOT/attachments/openapi/`). Falta el contrato de `/images` (decisión 6) |
| RF-20 | Colección Bruno | ❌ | No existen archivos `.bru` |

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
- Los tests escriben en una carpeta temporal. `.gitignore` excluye `priv/static/uploads/`.
- **Verificación:** `mix precommit` con 82 tests (4 nuevos). Prueba manual con `curl` contra el servidor de desarrollo: la foto se guardó, la URL devuelta respondió `200 image/jpeg` y el nombre quedó en `photo_url`.
- **Limitaciones:**
  - **Resuelto:** si la base de datos rechaza el alta o el `PATCH`, la foto recién subida se borra. Si un `PATCH` con foto nueva tiene éxito, se borra la anterior.
  - **Resuelto:** al eliminar un avistamiento (`soft_delete`) se borra su archivo, después de confirmar la transacción (`Aves.Bitacora.Changes.RemovePhotoFile`). La fila sigue en la base con su `photo_url`, oculta por `deleted_at` y sin archivo.
  - **Moderación:** retirar una foto (`hide`) no borra el archivo, para poder restaurarla.
  - La URL es relativa. La app móvil debe anteponer la URL base del servidor.
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

### Divergencias con el modelo original (`contexto.md`)

- `contexto.md` define PUBLICACION, LIKE y `views_count`, y prohíbe una tabla extra para populares. La implementación usa **`Sighting`** como publicación y creó **`bird_views`**. El `requisitos.adoc` no menciona likes. Hay que validarlo con el equipo.

### Pendientes por realizar (2026-10-22)

- **RF-16, gestión de usuarios desde admin:** endpoints para listar, editar, suspender y asignar roles por REST. Las acciones `assign_role` y `destroy` ya existen con sus policies.
- **RF-17, dashboard LiveView:** capa web para admins y moderadores, con login por sesión.
- **RF-19, OpenAPI completo:** falta documentar `/images` (los stubs de `birs_user_apis.yaml`), que depende de la decisión 6. Los endpoints del backend ya están en `birs_apis.yaml`.
- **RF-20, colección Bruno:** no existen archivos `.bru`.
- **Almacenamiento en producción:** la subida de fotos ya funciona en disco local (ver sección 0, "Subida de fotos"). Falta resolver dónde guardarlas en Fly.io, porque su disco es efímero (decisión 8).
- **Métricas para admin:** pendiente desde #10. El enunciado también pide un dashboard de Grafana con golden metrics.
- **Despliegue:** GitHub Actions y Fly.io, según el enunciado. Todavía no hay configuración en el repo.
- **Limpieza:**
  - Quitar o usar el router de AshJsonApi, que está vacío.
  - Mover `secret_key_base` y `token_signing_secret` de `config/dev.exs` a variables de entorno.
  - Actualizar `sesion_20261022.md`, que ya no describe el estado final de `bird_views`.
- **Commit:** el trabajo del 22-oct está sin commitear. El commit `480049e` existe solo en local.

### Pendientes por decidir (2026-10-22)

1. **Vistas del ranking (RF-15):** ¿cada visita cuenta o solo una por usuario? Hoy cuenta cada visita. ¿Las búsquedas y listados también suman o solo la ficha?
2. **Borrado de aves con avistamientos:** hoy responde 422. ¿Se bloquea siempre, se oculta con soft delete o se borra en cascada?
3. **Borrado de categorías con aves:** la FK no tiene `on_delete`. No está probado qué responde hoy.
4. **Estados del reporte:** el código usa `pendiente`, `aprobado` y `retirado`. El modelo original decía `pendiente`, `aceptado` y `rechazado`. Hay que elegir uno y alinear el contrato móvil.
5. **Login:** hoy solo entra con email. El nickname queda como mejora posible.
6. **Contrato móvil:** el OpenAPI de móvil usa `/images` y `PUT /images` para reportar. El backend expone `/api/photos` y `/api/reports`. Hay que decidir cuál se mantiene y avisar al equipo.
7. **Likes:** `contexto.md` los incluye y el enunciado no. Hay que decidir si se implementan.
8. **Almacenamiento de fotos:** en desarrollo ya se guarda en disco local (`priv/static/uploads`). Falta decidir el destino en producción: volumen de Fly.io, S3 u otro proveedor.
9. **Dashboard:** si admin y moderador comparten la misma vista o tienen permisos distintos.

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
- **Login por `email`**; `nickname` es una segunda identidad única (login por cualquiera de los dos queda como mejora futura).
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
