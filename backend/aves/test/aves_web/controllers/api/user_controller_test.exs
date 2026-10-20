# =============================================================================
# TESTS DEL CONTROLADOR DE USUARIO (API JSON)
# =============================================================================
#
# Archivo: test/aves_web/controllers/api/user_controller_test.exs
#
# ¿QUÉ PRUEBA ESTE ARCHIVO?
#   Los endpoints de autenticación y perfil expuestos por
#   `AvesWeb.API.UserController` bajo las rutas /api/user/*.
#
# RUTAS CUBIERTAS (definidas en lib/aves_web/router.ex):
#   POST   /api/user/signin  -> registro de un usuario nuevo
#   POST   /api/user/login   -> inicio de sesión
#   DELETE /api/user/logout  -> cierre de sesión (revoca el token)
#   GET    /api/user/me      -> perfil del usuario autenticado
#   PATCH  /api/user/me      -> edición del propio perfil
#
# ¿CÓMO SE EJECUTA? (desde la carpeta `aves/`)
#   mix test test/aves_web/controllers/api/user_controller_test.exs
#
# NOTAS:
#   * Usa `AvesWeb.ConnCase`, que entrega un `conn` limpio por test y aísla
#     la base de datos con el sandbox (los datos se revierten al terminar).
#   * La autenticación se hace con un token tipo bearer en la cabecera
#     HTTP `authorization`.
# =============================================================================
defmodule AvesWeb.API.UserControllerTest do
  use AvesWeb.ConnCase

  # Atributos de ejemplo reutilizados para registrar un usuario en varios tests.
  @register_attrs %{
    "email" => "ana@example.com",
    "nickname" => "ana",
    "password" => "supersecret123",
    "password_confirmation" => "supersecret123"
  }

  # Construye un `conn` (petición) con la cabecera `authorization` ya puesta,
  # para simular una petición autenticada con bearer token.
  defp authed(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
  end

  # ---------------------------------------------------------------------------
  # POST /api/user/signin  -> Registro de usuario
  # ---------------------------------------------------------------------------
  describe "POST /api/user/signin" do
    # Camino feliz: un registro válido crea el usuario y devuelve su token.
    test "registra un usuario y devuelve un bearer token", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)

      # 201 = Created. Respuesta esperada: %{"user" => %{...}, "token" => "..."}
      assert %{"user" => user, "token" => token} = json_response(conn, 201)
      assert user["email"] == "ana@example.com"
      assert user["nickname"] == "ana"
      # Todo usuario nuevo entra con el rol por defecto "usuario".
      assert user["rol"] == "usuario"
      assert is_binary(token)
    end

    # Validación de unicidad: el email no se puede repetir.
    test "rechaza un email ya registrado con 422", %{conn: conn} do
      post(conn, ~p"/api/user/signin", @register_attrs)
      conn = post(conn, ~p"/api/user/signin", @register_attrs)

      # 422 = Unprocessable Entity. Se espera una lista de errores no vacía.
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors != []
    end

    # La contraseña debe venir acompañada de su confirmación.
    test "rechaza password sin confirmación con 422", %{conn: conn} do
      attrs = Map.delete(@register_attrs, "password_confirmation")
      conn = post(conn, ~p"/api/user/signin", attrs)

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/user/login  -> Inicio de sesión
  # ---------------------------------------------------------------------------
  describe "POST /api/user/login" do
    # Each test registra primero un usuario para poder iniciar sesión.
    setup %{conn: conn} do
      post(conn, ~p"/api/user/signin", @register_attrs)
      :ok
    end

    # Camino feliz: login con email + password correctos.
    test "inicia sesión con email y password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "email" => "ana@example.com",
          "password" => "supersecret123"
        })

      # 200 = OK. Devuelve el usuario y un nuevo token.
      assert %{"user" => user, "token" => token} = json_response(conn, 200)
      assert user["email"] == "ana@example.com"
      assert is_binary(token)
    end

    # El campo puede llamarse "user" además de "email" (alias de login).
    test "acepta el campo `user` como alias de email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "user" => "ana@example.com",
          "password" => "supersecret123"
        })

      assert %{"token" => token} = json_response(conn, 200)
      assert is_binary(token)
    end

    # Credenciales incorrectas no deben dar acceso.
    test "rechaza credenciales inválidas con 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "email" => "ana@example.com",
          "password" => "incorrecta"
        })

      # 401 = Unauthorized.
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/user/logout  -> Cierre de sesión
  # ---------------------------------------------------------------------------
  describe "DELETE /api/user/logout" do
    # Cerrar sesión invalida/revoca el token enviado.
    test "revoca el bearer token enviado", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)
      %{"token" => token} = json_response(conn, 201)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/user/logout")

      # 204 = No Content (éxito sin cuerpo de respuesta).
      assert response(conn, 204)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/user/me  -> Perfil del usuario autenticado
  # ---------------------------------------------------------------------------
  describe "GET /api/user/me" do
    # Con un token válido devuelve los datos del propio usuario.
    test "devuelve el usuario autenticado con bearer token", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)
      %{"token" => token} = json_response(conn, 201)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/user/me")

      assert %{"user" => user} = json_response(conn, 200)
      assert user["email"] == "ana@example.com"
      assert user["nickname"] == "ana"
      assert user["rol"] == "usuario"
    end

    # Sin cabecera de autorización no hay acceso.
    test "sin token devuelve 401", %{conn: conn} do
      conn = get(conn, ~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end

    # Un token con formato inválido también es rechazado.
    test "con token inválido devuelve 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer token.invalido.aqui")
        |> get(~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/user/me  -> Edición del propio perfil
  # ---------------------------------------------------------------------------
  describe "PATCH /api/user/me" do
    # Cada test crea un usuario y expone su token como contexto (%{token: ...}).
    setup %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)
      %{"token" => token} = json_response(conn, 201)
      %{token: token}
    end

    # El usuario puede cambiar su propio nickname.
    test "actualiza el nickname del propio usuario", %{token: token} do
      conn = patch(authed(token), ~p"/api/user/me", %{"nickname" => "ana_nueva"})

      assert %{"user" => user} = json_response(conn, 200)
      assert user["nickname"] == "ana_nueva"
      # El resto de campos permanecen intactos.
      assert user["email"] == "ana@example.com"
      assert user["rol"] == "usuario"
    end

    # El usuario puede cambiar su propio email.
    test "actualiza el email del propio usuario", %{token: token} do
      conn = patch(authed(token), ~p"/api/user/me", %{"email" => "nueva@example.com"})

      assert %{"user" => user} = json_response(conn, 200)
      assert user["email"] == "nueva@example.com"
      assert user["nickname"] == "ana"
    end

    # Seguridad: el campo "rol" enviado por el cliente se ignora.
    test "ignora el intento de cambiar el rol", %{token: token} do
      conn = patch(authed(token), ~p"/api/user/me", %{"nickname" => "ana2", "rol" => "admin"})

      assert %{"user" => user} = json_response(conn, 200)
      assert user["nickname"] == "ana2"
      # El rol sigue siendo "usuario", NO "admin".
      assert user["rol"] == "usuario"
    end

    # Un nickname ya usado por otro usuario debe rechazarse.
    test "rechaza un nickname ya usado con 422", %{token: token, conn: conn} do
      # Creamos un segundo usuario que "reserva" el nickname "beto".
      post(conn, ~p"/api/user/signin", %{
        "email" => "beto@example.com",
        "nickname" => "beto",
        "password" => "supersecret123",
        "password_confirmation" => "supersecret123"
      })

      conn = patch(authed(token), ~p"/api/user/me", %{"nickname" => "beto"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors != []
    end

    # Un email ya usado por otro usuario debe rechazarse.
    test "rechaza un email ya usado con 422", %{token: token, conn: conn} do
      post(conn, ~p"/api/user/signin", %{
        "email" => "beto@example.com",
        "nickname" => "beto",
        "password" => "supersecret123",
        "password_confirmation" => "supersecret123"
      })

      conn = patch(authed(token), ~p"/api/user/me", %{"email" => "beto@example.com"})

      assert %{"errors" => _} = json_response(conn, 422)
    end

    # No se puede editar el perfil sin estar autenticado.
    test "sin token devuelve 401", %{conn: conn} do
      conn = patch(conn, ~p"/api/user/me", %{"nickname" => "intruso"})

      assert %{"error" => _} = json_response(conn, 401)
    end
  end
end
