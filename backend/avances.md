# Avances Backend — Bitácora de Aves

> Resumen de la implementación realizada hasta ahora.
> **Última actualización:** 2026-10-14
> **Issues trabajados:** #9 — Registro e inicio de sesión (RF-01, RF-02) · #10 — Roles de usuario (RF-03).
> La base de autenticación (bearer) de #9 la reutilizan #10 y #11.

## Contexto

- **Stack:** Elixir 1.20 / OTP 29 · Phoenix 1.8 · Ash 3 · AshAuthentication 4 · AshPostgres · PostgreSQL 16.
- **App:** `aves/` (dentro de `backend/`).
- **Contrato móvil (OpenAPI):** `../docs/modules/ROOT/attachments/openapi/birs_user_apis.yaml`.
- **Base de datos local:** `docker-compose.yaml` (raíz del repo) → servicio `db` = `postgres:16` en `localhost:5432` (usuario/clave `postgres`).

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

## 6. Archivos involucrados

```
backend/
├── avances.md                                  ← este documento
└── aves/
    ├── lib/aves/accounts.ex                    (modificado — create_admin/1)
    ├── lib/aves/accounts/user.ex               (modificado — roles y policies)
    ├── lib/aves_web/auth_plug.ex               (nuevo en #9)
    ├── lib/aves_web/controllers/api/user_controller.ex   (nuevo en #9)
    ├── lib/aves_web/router.ex                  (modificado en #9)
    ├── lib/mix/tasks/aves.create_admin.ex      (nuevo)
    ├── test/aves/accounts/user_policies_test.exs          (nuevo)
    ├── test/aves_web/controllers/api/user_controller_test.exs (nuevo en #9)
    └── priv/repo/migrations/20261009122556_add_user_auth_fields.exs (nuevo en #9)
```

---

## 7. Verificación realizada

- `mix precommit` → **30 tests pasan** (15 de autenticación de #9 + 15 de roles de #10).
- **Matriz de roles** cubierta por tests (`Ash.can?`): usuario no puede asignar roles ni
  eliminar; moderador elimina solo a `usuario` (no a otros moderadores ni admins);
  admin puede todo; invitado sin acceso.
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

## 8. Cómo levantar el backend

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

## 9. Decisiones de diseño

- **PK UUID** en todo el modelo (consistencia con el scaffold; IDs no adivinables en la API pública).
- **Login por `email`**; `nickname` es una segunda identidad única (login por cualquiera de los dos queda como mejora futura).
- **Tokens stateful/revocables** (permiten logout real y `log_out_everywhere`), a costa de una consulta a BD por request.
- **Prefijo `/api`** para los endpoints REST.
- **Opción A** para exponer auth: controlador Phoenix (control explícito del token en la respuesta) en lugar de rutas de AshJsonApi.
- **Autorización por roles con policies de Ash** (no en el controlador): el rol se evalúa con `actor_attribute_equals/2` y `expr(...)`, de modo que las mismas reglas valen para REST y para el dashboard LiveView.
- **Bypass controlado para el bootstrap**: `create_admin` usa `authorize?: false` porque ninguna policy puede autorizar la creación del primer admin.

---

## 10. Pendientes / siguientes pasos

- **#11 Perfil de usuario:** edición de perfil (`PATCH/PUT /api/user/me`); el usuario ya puede leer su propio perfil por policy.
- **Endpoints/dashboard de administración:** listar usuarios, asignar rol (`assign_role`) y eliminar usuarios desde REST/LiveView, reutilizando las acciones y policies ya definidas.
- **Permisos de publicaciones/colecciones/reportes:** aplicar el mismo patrón de roles cuando existan esos recursos (#13/#14).
- **Login del dashboard web:** por sesión en LiveView (no bearer), reutilizando las mismas acciones.
- **Contrato `/images`:** actualizar body/respuestas y `POST /reportes` en sus issues (#13/#14).
- **Métricas (admin):** "acceso a métricas de datos" queda para la feature de métricas.
