# Avances Backend — Bitácora de Aves

> Resumen de la implementación realizada hasta ahora.
> **Última actualización:** 2026-10-09
> **Issue trabajado:** #9 — BACKEND: Registro e inicio de sesión (RF-01, RF-02).
> Incluye la base de autenticación (bearer) que reutilizan #10 y #11.

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
protegidos de #10, #11, #14, etc.

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

## 5. Archivos involucrados

```
backend/
├── avances.md                                  ← este documento
└── aves/
    ├── lib/aves/accounts/user.ex               (modificado)
    ├── lib/aves_web/auth_plug.ex               (nuevo)
    ├── lib/aves_web/controllers/api/user_controller.ex   (nuevo)
    ├── lib/aves_web/router.ex                  (modificado)
    ├── test/aves_web/controllers/api/user_controller_test.exs (nuevo)
    └── priv/repo/migrations/20261009122556_add_user_auth_fields.exs (nuevo)
```

---

## 6. Verificación realizada

- `mix precommit` → **15 tests pasan** (incluye 10 de autenticación).
- **Prueba HTTP real** (servidor levantado + curl), ciclo completo del token:

  | Paso | Resultado |
  |---|---|
  | Registro → token | ✅ |
  | `GET /api/user/me` con token | `200` + usuario |
  | `GET /api/user/me` sin token | `401` |
  | `DELETE /api/user/logout` | `204` |
  | `GET /api/user/me` con token revocado | `401` (revocación real) |

---

## 7. Cómo levantar el backend

```bash
# 1. Base de datos (desde la raíz del repo)
docker compose up -d db

# 2. Migraciones y servidor (desde backend/aves)
mix deps.get
mix ecto.create && mix ash.migrate
mix phx.server
```

---

## 8. Decisiones de diseño

- **PK UUID** en todo el modelo (consistencia con el scaffold; IDs no adivinables en la API pública).
- **Login por `email`**; `nickname` es una segunda identidad única (login por cualquiera de los dos queda como mejora futura).
- **Tokens stateful/revocables** (permiten logout real y `log_out_everywhere`), a costa de una consulta a BD por request.
- **Prefijo `/api`** para los endpoints REST.
- **Opción A** para exponer auth: controlador Phoenix (control explícito del token en la respuesta) en lugar de rutas de AshJsonApi.

---

## 9. Pendientes / siguientes pasos

- **#10 Roles de usuario:** policies de Ash que exijan `actor` con `rol` (admin/moderador); acceso al dashboard.
- **#11 Perfil de usuario:** edición de perfil (`PATCH/PUT /api/user/me`).
- **Seed de administrador:** hoy no hay forma de crear el primer `admin`/`moderador` (el `rol` no se acepta en el registro).
- **Login del dashboard web:** por sesión en LiveView (no bearer), reutilizando las mismas acciones.
- **Contrato `/images`:** actualizar body/respuestas y `POST /reportes` en sus issues (#13/#14).
