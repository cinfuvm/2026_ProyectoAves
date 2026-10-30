# Guía de los tests de usuarios

Documentación práctica para ejecutar, entender y extender los tests
relacionados con usuarios en el backend (`aves`).

---

## 1. Archivos de tests

| Archivo | Tipo | Qué cubre | Nº de tests |
|---|---|---|---|
| `test/aves_web/controllers/api/user_controller_test.exs` | Integración HTTP | Endpoints `/api/user/*` (registro, login, logout, perfil) | 16 |
| `test/aves/accounts/user_policies_test.exs` | Políticas | Autorización por rol sobre el recurso `User` | 17 |

---

## 2. Requisitos previos

1. Tener PostgreSQL disponible y la configuración de `config/test.exs` correcta.
2. Instalar dependencias y **crear/migrar la base de datos de test** (sólo la primera vez):

   ```bash
   mix deps.get
   mix ash.setup
   ```

   > El alias `mix test` ya ejecuta `ash.setup --quiet` automáticamente antes
   > de correr los tests, así que normalmente no hace falta nada manual.

---

## 3. Cómo ejecutar los tests

Todos los comandos se ejecutan **desde la carpeta `aves/`**:

```bash
cd backend/aves
```

### Ejecutar sólo los tests de usuarios

```bash
# El test de la API/controlador
mix test test/aves_web/controllers/api/user_controller_test.exs

# El test de políticas de roles
mix test test/aves/accounts/user_policies_test.exs

# Ambos a la vez (varios archivos en el mismo comando)
mix test test/aves_web/controllers/api/user_controller_test.exs \
         test/aves/accounts/user_policies_test.exs
```

### Ejecutar un solo test por su línea

Añade `:linea` al final del archivo:

```bash
mix test test/aves_web/controllers/api/user_controller_test.exs:49
```

### Ejecutar por nombre (describe/tag)

```bash
mix test test/aves_web/controllers/api/user_controller_test.exs --only login
```

### Otros comandos útiles

```bash
# Toda la suite del proyecto
mix test

# Sólo los tests que fallaron en la última corrida
mix test --failed

# Ver el detalle de cada test (no sólo puntos)
mix test --trace

# Detenerte en el primer fallo
mix test --max-failures 1

# Correr todo lo que contiene "user" en la ruta
mix test test/aves/**/user_*.exs
```

---

## 4. Cómo leer la salida

```
......

Finished in 0.4 seconds (0.00s async, 0.4s sync)
16 tests, 0 failures
```

- Un punto (`.`) = test que pasó.
- `F` = test que falló (te muestra el `assert` que rompió).
- `16 tests, 0 failures` = todo bien.

---

## 5. Cómo entender cada archivo

### 5.1 `user_controller_test.exs` (API)

Simula peticiones HTTP reales con `Phoenix.ConnTest` y verifica el JSON y el
código de estado. Bloques `describe`:

- **`POST /api/user/signin`** — registro; devuelve `201` con `user` + `token`; `422` en email duplicado o sin confirmación.
- **`POST /api/user/login`** — login con `email` o su alias `user`; `200` con token; `401` en credenciales inválidas.
- **`DELETE /api/user/logout`** — revoca el token; responde `204`.
- **`GET /api/user/me`** — perfil; `200` con token válido, `401` sin token o token inválido.
- **`PATCH /api/user/me`** — edita nickname/email; ignora cambios de `rol`; `422` en datos duplicados; `401` sin token.

Detalles clave:

- `authed(token)` arma un `conn` con la cabecera `authorization: Bearer <token>`.
- `json_response(conn, 201)` convierte la respuesta en mapa y valida el status.
- La base de datos se aísla con el sandbox (cada test parte de cero).

### 5.2 `user_policies_test.exs` (autorización)

No hace peticiones HTTP: pregunta directamente a Ash si un actor puede hacer
una acción, con `Ash.can?({recurso, accion}, actor)`.

Roles:

| Rol | leer perfiles | editar su perfil | editar otros | eliminar | asignar roles |
|---|---|---|---|---|---|
| `:admin` | ✅ | ✅ | — | ✅ (a cualquiera) | ✅ |
| `:moderador` | ✅ (a cualquiera) | ✅ | — | ✅ (a usuarios comunes) | ❌ |
| `:usuario` | ✅ (sólo el suyo) | ✅ | ❌ | ❌ | ❌ |
| invitado (`nil`) | ❌ | ❌ | ❌ | ❌ | ❌ |

Helpers internos:

- `register/0` — crea un usuario con el flujo real de autenticación.
- `create_user(:usuario | :moderador | :admin)` — crea un usuario con ese rol.
- `authorize?: false` al preparar datos = "no apliques políticas, sólo crea".

Bloques `describe`: `update :assign_role`, `read`, `destroy`,
`update :update_profile` y `create_admin/1`.

---

## 6. Cómo añadir un test nuevo

1. **Ubica el bloque `describe`** de la sección que quieres cubrir
   (o crea uno nuevo si es un endpoint/acción distinta).
2. **Escribe el `test "descripción en español" do ... end`** con:
   - **Arrange:** prepara datos (registrar usuario, crear token, etc.).
   - **Act:** ejecuta la acción (`post/3`, `patch/3`, `Ash.can?/2`, ...).
   - **Assert:** verifica status + cuerpo con `json_response/2` o
     `assert`/`refute`.
3. **Usa los helpers existentes** (`authed/1`, `register/0`, `create_user/1`)
   en lugar de duplicar código.
4. **Corre sólo ese test** para iterar rápido:

   ```bash
   mix test test/ruta/al/archivo.exs:LINEA
   ```

### Ejemplo: nuevo test en el controlador

```elixir
test "no permite registrar sin email", %{conn: conn} do
  attrs = Map.delete(@register_attrs, "email")
  conn = post(conn, ~p"/api/user/signin", attrs)

  assert %{"errors" => errors} = json_response(conn, 422)
  assert errors != []
end
```

### Ejemplo: nuevo test de política

```elixir
test "un moderador no puede editar el perfil de otro" do
  moderador = create_user(:moderador)
  other = create_user(:usuario)

  refute Ash.can?({other, :update_profile}, moderador)
end
```

---

## 7. Buenas prácticas del proyecto

- Los tests de datos usan `Aves.DataCase, async: true` (corren en paralelo).
- Usa `start_supervised!/1` si levantas procesos; evita `Process.sleep/1`.
- Antes de dar por terminado un cambio, ejecuta el alias de precommit desde
  `aves/`:

  ```bash
  mix precommit
  ```

  que corre compilación con warnings como errores, formato y toda la suite.

---

## 8. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `connection refused` / no conecta a la DB | PostgreSQL apagado o mal configurado en `config/test.exs` | Enciende Postgres y revisa la config |
| `database ... does not exist` | La base de test no está creada/migrada | `mix ash.setup` (o `mix ecto.create && mix ecto.migrate` en `MIX_ENV=test`) |
| Fallos aleatorios de datos | Vestigios entre corridas | Los tests ya usan sandbox; si persiste, `mix ecto.reset` |
| `--only login` no encuentra tests | Etiqueta inexistente | Revisa el nombre del tag; usa `--trace` para listar |
