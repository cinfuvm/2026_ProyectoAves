defmodule LandingWeb.AuthControllerTest do
  use LandingWeb.ConnCase

  setup do
    Req.Test.stub(:landing_aves_api, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      params = if body == "", do: %{}, else: Jason.decode!(body)

      send(
        self(),
        {:api_request, conn.method, conn.request_path, params,
         Plug.Conn.get_req_header(conn, "authorization")}
      )

      case {conn.method, conn.request_path, params["password"]} do
        {"POST", "/api/user/login", "wrong-password"} ->
          conn
          |> Plug.Conn.put_status(:unauthorized)
          |> Req.Test.json(%{"error" => "Credenciales inválidas"})

        {"POST", "/api/user/signin", "existing-password"} ->
          conn
          |> Plug.Conn.put_status(:unprocessable_entity)
          |> Req.Test.json(%{"errors" => ["El nombre de usuario ya está en uso."]})

        {"DELETE", "/api/user/logout", _password} ->
          if Plug.Conn.get_req_header(conn, "authorization") == ["Bearer active-token"] do
            Plug.Conn.resp(conn, :service_unavailable, "")
          else
            Plug.Conn.resp(conn, :no_content, "")
          end

        {"POST", _path, _password} ->
          Req.Test.json(conn, %{
            "token" =>
              if(params["email"] == "logout-failure@example.com",
                do: "active-token",
                else: "test-bearer-token"
              ),
            "user" => %{
              "id" => "user-id",
              "email" => params["email"],
              "nickname" => params["nickname"] || "observador",
              "rol" => "usuario"
            }
          })
      end
    end)

    :ok
  end

  test "signup sends the backend fields, stores its token, and redirects", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/signup/")

    conn =
      post(conn, "/signup/", %{
        "_csrf_token" => csrf_token,
        "username" => "observador",
        "email" => "bird@example.com",
        "password" => "secure-password",
        "password_confirmation" => "secure-password"
      })

    assert redirected_to(conn) == "/propaganda/"
    assert get_session(conn, "token") == "test-bearer-token"
    assert get_session(conn, "current_user")["nickname"] == "observador"

    assert_received {:api_request, "POST", "/api/user/signin", payload, []}
    assert payload["nickname"] == "observador"
    assert payload["password_confirmation"] == "secure-password"
  end

  test "login authenticates with the backend and stores its token", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/login/")

    conn =
      post(conn, "/login/", %{
        "_csrf_token" => csrf_token,
        "email" => "bird@example.com",
        "password" => "secure-password"
      })

    assert redirected_to(conn) == "/propaganda/"
    assert get_session(conn, "token") == "test-bearer-token"

    assert_received {:api_request, "POST", "/api/user/login", %{"email" => "bird@example.com"},
                     []}
  end

  test "signup rejects mismatched passwords without calling the backend", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/signup/")

    conn =
      post(conn, "/signup/", %{
        "_csrf_token" => csrf_token,
        "username" => "observador",
        "email" => "bird@example.com",
        "password" => "secure-password",
        "password_confirmation" => "different-password"
      })

    assert redirected_to(conn) == "/signup/"
    refute_received {:api_request, _, _, _, _}

    conn = get(recycle(conn), "/signup/")
    assert response(conn, 200) =~ "Las contraseñas no coinciden."
  end

  test "login shows backend authentication errors", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/login/")

    conn =
      post(conn, "/login/", %{
        "_csrf_token" => csrf_token,
        "email" => "bird@example.com",
        "password" => "wrong-password"
      })

    assert redirected_to(conn) == "/login/"
    conn = get(recycle(conn), "/login/")
    assert response(conn, 200) =~ "El correo o la contraseña no son correctos."
  end

  test "logout revokes the token and clears the session", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/login/")

    conn =
      post(conn, "/login/", %{
        "_csrf_token" => csrf_token,
        "email" => "bird@example.com",
        "password" => "secure-password"
      })

    conn = get(recycle(conn), "/propaganda/")
    assert response(conn, 200) =~ "Hola, observador"

    [csrf_token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, response(conn, 200),
        capture: :all_but_first
      )

    conn =
      post(conn, "/logout/", %{
        "_csrf_token" => csrf_token
      })

    assert redirected_to(conn) == "/propaganda/"
    assert get_session(conn, "token") == nil

    assert_received {:api_request, "DELETE", "/api/user/logout", %{},
                     ["Bearer test-bearer-token"]}
  end

  test "failed logout keeps the session and shows an error", %{conn: conn} do
    {conn, csrf_token} = get_form(conn, "/login/")

    conn =
      post(conn, "/login/", %{
        "_csrf_token" => csrf_token,
        "email" => "logout-failure@example.com",
        "password" => "secure-password"
      })

    conn = get(recycle(conn), "/propaganda/")

    [csrf_token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, response(conn, 200),
        capture: :all_but_first
      )

    conn = post(conn, "/logout/", %{"_csrf_token" => csrf_token})

    assert redirected_to(conn) == "/propaganda/"
    assert get_session(conn, "token") == "active-token"

    conn = get(recycle(conn), "/propaganda/")
    assert response(conn, 200) =~ "No se pudo confirmar el cierre de sesión con el servidor."
  end

  defp get_form(conn, path) do
    conn = get(conn, path)
    html = response(conn, 200)

    [csrf_token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, html, capture: :all_but_first)

    [form_token] =
      Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html, capture: :all_but_first)

    assert form_token == csrf_token
    {conn, csrf_token}
  end
end
