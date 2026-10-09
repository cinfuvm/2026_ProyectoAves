defmodule AvesWeb.API.UserControllerTest do
  use AvesWeb.ConnCase

  @register_attrs %{
    "email" => "ana@example.com",
    "nickname" => "ana",
    "password" => "supersecret123",
    "password_confirmation" => "supersecret123"
  }

  describe "POST /api/user/signin" do
    test "registra un usuario y devuelve un bearer token", %{conn: conn} do
      conn = post(conn, ~p"/api/user/signin", @register_attrs)

      assert %{"user" => user, "token" => token} = json_response(conn, 201)
      assert user["email"] == "ana@example.com"
      assert user["nickname"] == "ana"
      assert user["rol"] == "usuario"
      assert is_binary(token)
    end

    test "rechaza un email ya registrado con 422", %{conn: conn} do
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
  end

  describe "POST /api/user/login" do
    setup %{conn: conn} do
      post(conn, ~p"/api/user/signin", @register_attrs)
      :ok
    end

    test "inicia sesión con email y password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "email" => "ana@example.com",
          "password" => "supersecret123"
        })

      assert %{"user" => user, "token" => token} = json_response(conn, 200)
      assert user["email"] == "ana@example.com"
      assert is_binary(token)
    end

    test "acepta el campo `user` como alias de email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "user" => "ana@example.com",
          "password" => "supersecret123"
        })

      assert %{"token" => token} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "rechaza credenciales inválidas con 401", %{conn: conn} do
      conn =
        post(conn, ~p"/api/user/login", %{
          "email" => "ana@example.com",
          "password" => "incorrecta"
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
end
