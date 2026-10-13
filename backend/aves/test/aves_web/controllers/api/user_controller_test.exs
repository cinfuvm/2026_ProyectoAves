defmodule AvesWeb.API.UserControllerTest do
  use AvesWeb.ConnCase

  # El contrato (`birds_apis.yaml`) llama `user` al identificador público.
  @register_attrs %{
    "user" => "ana.rios",
    "password" => "supersecret123",
    "password_confirmation" => "supersecret123"
  }

  describe "POST /api/user/signin" do
    test "registra un usuario y devuelve un bearer token", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)

      assert %{"user" => user, "token" => token} = json_response(conn, 201)
      assert user["user"] == "ana.rios"
      assert user["rol"] == "usuario"
      assert is_binary(token)
    end

    test "rechaza un usuario ya registrado con 422", %{conn: conn} do
      post(conn, ~p"/api/user/signin", @register_attrs)
      conn = post(conn, ~p"/api/user/signin", @register_attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors != []
    end

    test "rechaza password sin confirmación con 422", %{conn: conn} do
      attrs = Map.delete(@register_attrs, "password_confirmation")
      conn = post(conn, ~p"/api/user/signin", attrs)

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "rechaza un usuario demasiado corto con 422", %{conn: conn} do
      attrs = Map.put(@register_attrs, "user", "ab")
      conn = post(conn, ~p"/api/user/signin", attrs)

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "ignora el campo `email`", %{conn: conn} do
      attrs =
        @register_attrs
        |> Map.delete("user")
        |> Map.put("email", "ana.rios")

      conn = post(conn, ~p"/api/user/signin", attrs)

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "POST /api/user/login" do
    setup %{conn: conn} do
      post(conn, ~p"/api/user/signin", @register_attrs)
      :ok
    end

    test "inicia sesión con usuario y password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "user" => "ana.rios",
          "password" => "supersecret123"
        })

      assert %{"user" => user, "token" => token} = json_response(conn, 200)
      assert user["user"] == "ana.rios"
      assert is_binary(token)
    end

    test "el usuario no distingue mayúsculas", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "user" => "ANA.RIOS",
          "password" => "supersecret123"
        })

      assert %{"token" => token} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "rechaza credenciales inválidas con 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "user" => "ana.rios",
          "password" => "incorrecta"
        })

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "ignora el campo `email` y responde 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "email" => "ana.rios",
          "password" => "supersecret123"
        })

      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "DELETE /api/user/logout" do
    test "revoca el bearer token enviado", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)
      %{"token" => token} = json_response(conn, 201)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/user/logout")

      assert response(conn, 204)
    end
  end

  describe "GET /api/user/me" do
    test "devuelve el usuario autenticado con bearer token", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)
      %{"token" => token} = json_response(conn, 201)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/user/me")

      assert %{"user" => user} = json_response(conn, 200)
      assert user["user"] == "ana.rios"
      assert user["rol"] == "usuario"
    end

    test "sin token devuelve 401", %{conn: conn} do
      conn = get(conn, ~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "con token inválido devuelve 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer token.invalido.aqui")
        |> get(~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end
  end
end
