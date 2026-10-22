# Backend de Aves: visión general

> Descripción de cómo funciona el backend y qué hace cada parte.
> Última revisión: 2026-10-22. Para el estado de los requisitos ver `avances.md`.

**Stack:** Elixir 1.20, Phoenix 1.8, Ash 3 (con AshPostgres y AshAuthentication) y PostgreSQL 16. La aplicación OTP se llama `:aves` y vive en `backend/aves/`.

**Idea central:** los recursos de Ash definen los datos, las acciones y las reglas de acceso (policies) en un solo lugar. Los controllers de Phoenix son delgados: reciben la petición, la traducen a una acción de Ash y devuelven JSON. Por eso la misma regla de permisos aplica igual a la API REST y al dashboard LiveView previsto.

---

## 1. Arranque de la aplicación

- **`lib/aves/application.ex`** levanta el árbol de procesos en este orden: telemetría, `Aves.Repo` (conexión a PostgreSQL), DNSCluster, `Phoenix.PubSub`, el `Endpoint` y `AshAuthentication.Supervisor`.
- **`lib/aves/repo.ex`** es el repositorio Ecto. Ash lo usa a través de AshPostgres.
- **`lib/aves/secrets.ex`** entrega la clave de firma de tokens (`token_signing_secret`) a AshAuthentication.
- **`lib/aves/mailer.ex`** está configurado con Swoosh, pero no hay envío de correos todavía.
- **`lib/aves_web.ex`** define los macros `use AvesWeb, :controller` y `:html`, que importan los helpers comunes.

## 2. Configuración

- **`config/config.exs`** es la base común. Registra el repo, el endpoint, el mailer y la configuración de AshAuthentication.
- **`config/dev.exs`**, **`prod.exs`** y **`test.exs`** ajustan cada entorno.
- **`config/runtime.exs`** lee variables de entorno en producción: `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT` (por defecto 4000) y `DNS_CLUSTER_QUERY`.
- La base de datos de desarrollo corre con Docker: el `docker-compose.yaml` de la raíz del repo levanta `postgres:16` en `localhost:5432`.

## 3. Router y pipelines

**`lib/aves_web/router.ex`** define cuatro grupos de rutas:

| Scope | Pipeline | Qué contiene |
|---|---|---|
| `/api/json` | `:api` | Swagger UI y el router de AshJsonApi. Está vacío (`domains: []`), así que no expone nada. |
| `/api` (públicas) | `:api` | `POST /user/signin`, `POST /user/login`, `DELETE /user/logout`. |
| `/api` (autenticadas) | `:api_auth` | Todo lo demás: usuario, aves, categorías, avistamientos, fotos, colección y reportes. |
| `/` | `:browser` | Página Phoenix por defecto (`PageController`). |

El pipeline `:api_auth` incluye **`AuthPlug`**, que se describe en la sección 4.

## 4. Autenticación

**`lib/aves/accounts/token.ex`** y **`lib/aves/accounts/user.ex`** usan AshAuthentication con la estrategia de contraseña:

- Login por **email**. El nickname también es único.
- La contraseña se guarda como `hashed_password` (bcrypt).
- Los tokens son **JWT con estado**: se guardan en la tabla de tokens y se pueden revocar. Por eso el logout es real.
- El campo `rol` es un átomo con tres valores: `usuario` (por defecto), `moderador` y `admin`.

**`lib/aves_web/auth_plug.ex`** lee `Authorization: Bearer <token>`, carga al usuario y lo registra como **actor** de Ash con `Ash.PlugHelpers.set_actor`. Si el token falta o no es válido, responde 401. Con `require: false` no exige token (no se usa hoy).

A partir de ahí, cada acción de Ash recibe el actor y evalúa sus policies.

**`lib/aves_web/controllers/api/user_controller.ex`** expone registro, login, logout, `GET /me` y `PATCH /me`. No implementa autenticación por su cuenta: delega en las acciones generadas por AshAuthentication. Acepta `user` como alias de `email` y `confirm_password` como alias de `password_confirmation`, por compatibilidad con el contrato OpenAPI inicial.

## 5. Dominios y recursos

Un **dominio** agrupa recursos relacionados. Hay cuatro, y cada uno declara sus recursos en un bloque `resources`.

### `Aves.Accounts`: usuarios y tokens

- **`User`**: `email`, `nickname`, `hashed_password`, `rol`.
  - Acciones: `read`, `destroy`, `assign_role` (solo admin) y `update_profile` (el propio usuario, solo nickname y email).
  - Policies: el admin hace todo; cada usuario lee su perfil; el moderador lee cualquier usuario y elimina solo a los de rol `usuario`.
- **`Token`**: guarda los tokens emitidos, sus fechas de expiración y permite revocarlos.
- **`create_admin/1`** (en `accounts.ex`) crea o promueve un administrador con `authorize?: false`. Es necesario porque ninguna policy permite crear el primer admin. Se usa con `mix aves.create_admin`.

### `Aves.Catalog`: aves, categorías y vistas

- **`Category`**: `name` (único). Cualquier usuario autenticado la lee. Solo moderadores y admins la crean, editan o borran.
- **`Bird`**: `name`, `scientific_name` (único), `description` y `category_id` (opcional). Tiene `has_many :photos` con los avistamientos visibles.
  - Lectura para cualquier usuario autenticado. Escritura solo para moderadores y admins.
- **`BirdView`**: una fila por cada vez que alguien abre la ficha de un ave. Las vistas se borran en cascada cuando se borra el ave. Es la fuente del ranking de aves populares (RF-15).

### `Aves.Bitacora`: avistamientos y colección

- **`Sighting`** es el recurso central. Es la "publicación" del modelo original: `place`, `spotted_on`, `comment`, `photo_url`, `owner`, `bird`, además de `hidden_at` y `deleted_at` para ocultar o borrar lógicamente.
  - Acciones: `register` (RF-08), `update` y `soft_delete` (RF-09, solo el dueño), `hide` (moderador, RF-14), `personal_log` (RF-10, paginada) y `public` (RF-11, fotos de otros usuarios, paginada).
  - Policies: el dueño ve sus avistamientos aunque estén ocultos. Los demás solo ven los visibles, y los moderadores y admins ven todos.
- **`CollectionItem`**: guarda un avistamiento de otro usuario en la colección personal (RF-12). Hay una restricción única para no repetir el mismo par dueño-avistamiento.

### `Aves.Moderation`: reportes

- **`Report`**: `reason`, `status` y referencias a `reporter` y `sighting`.
  - `status` pasa por `pendiente` (al crearse), `aprobado` o `retirado`.
  - Cualquier usuario autenticado reporta (RF-13).
  - Solo moderadores y admins aprueban o retiran (RF-14).
  - Retirar un reporte también oculta el avistamiento: el controller llama a la acción `hide` de `Sighting`.

## 6. Controllers de la API

Viven en `lib/aves_web/controllers/api/`. Cada uno corresponde a un recurso:

| Controller | Endpoints |
|---|---|
| `UserController` | Registro, login, logout, perfil |
| `BirdController` | Buscar, listar, ver ficha (registra vista), crear, editar, borrar, ranking |
| `CategoryController` | CRUD de categorías |
| `SightingController` | Registrar, listar la bitácora, editar, borrar |
| `PhotoController` | Fotos de otros usuarios, filtrables por ave o categoría |
| `CollectionController` | Listar, agregar y quitar de la colección |
| `ReportController` | Reportar, listar la cola, aprobar, retirar |

**`helpers.ex`** concentra lo que comparten:

- `actor/1` obtiene el usuario autenticado.
- `page_opts/1` traduce `page` y `per_page` a paginación de Ash.
- `error_response/3` devuelve errores en JSON y convierte cualquier `Ash.Error.Forbidden` en 403.
- `sighting_json/1` y `put_if/4` sirven para serializar y armar los atributos desde los parámetros.

Cada controller sigue el mismo patrón: arma los atributos, llama a `Ash.create`, `Ash.read`, `Ash.update` o `Ash.destroy` con el actor, y responde.

## 7. Base de datos y migraciones

- **Migraciones** (`priv/repo/migrations/`): cinco en total, en orden cronológico. La última crea `bird_views` con su índice y el borrado en cascada.
- **Snapshots** (`priv/resource_snapshots/`): describen el estado de cada recurso. Ash los compara con el código al ejecutar `mix ash.codegen`.
- **Regla del proyecto:** toda migración de recursos se genera con `mix ash.codegen <nombre>`, no a mano. Si el código cambia sin codegen, el servidor de desarrollo falla al arrancar (`CheckCodegenStatus`). `mix ash.codegen --check` verifica que no haya cambios pendientes.
- **Seeds** (`priv/repo/seeds.exs`): datos de demo idempotentes. Crean un usuario, un moderador y un admin con contraseña `supersecret123`, además de categorías, aves y avistamientos.

## 8. Pruebas

- **`test/support/factory.ex`** tiene los helpers que usan los tests: `user_with_token/1`, `category/1`, `bird/1`, `sighting/2` y `sign_in_conn/2`.
- **`test/support/conn_case.ex`** y **`data_case.ex`** dan el contexto para tests de controllers y de datos.
- **Tests de controllers** (`test/aves_web/controllers/api/`) cubren cada endpoint con los roles relevantes.
- **Tests de políticas** (`test/aves/accounts/user_policies_test.exs`) verifican la matriz de roles con `Ash.can?`.
- **`mix precommit`** compila con warnings como error, formatea, deshace locks y corre todos los tests. Hoy son 78.

## 9. Un ejemplo: `GET /api/birds/:id`

1. El **endpoint** y el **router** envían la petición al pipeline `:api_auth`.
2. **`AuthPlug`** valida el token y pone al usuario como actor.
3. **`BirdController.show`** llama a `fetch_bird` (un `Ash.get` con el actor). La policy de lectura de `Bird` decide si puede verla.
4. Se carga la categoría y las últimas 50 fotos, cada una filtrada por las policies de `Sighting`.
5. Se registra una fila en `bird_views`. Si falla, la respuesta sigue igual.
6. Se responde el JSON con la ficha.

## 10. Lo que todavía no existe o es provisional

- **Fotos:** `photo_url` es solo un string. No hay subida de archivos ni almacenamiento.
- **AshJsonApi:** el router está configurado pero sin dominios, así que no expone nada.
- **Dashboard LiveView:** pendiente. `PageController` sigue con la página por defecto de Phoenix.
- **RF-16 y RF-20:** gestión de usuarios desde el admin y colección Bruno, sin implementar.
- **Secretos en `config/dev.exs`:** hay una `secret_key_base` y un `token_signing_secret` escritos en el archivo. Son de desarrollo, pero están en el repositorio. Conviene moverlos a variables de entorno o a un archivo ignorado antes de desplegar.
