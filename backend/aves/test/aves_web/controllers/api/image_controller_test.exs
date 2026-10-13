defmodule AvesWeb.API.ImageControllerTest do
  use AvesWeb.ConnCase

  alias Aves.Media.{Image, Report}

  # Contraseña con la que se registran todos los usuarios de estos tests.
  @password "supersecret123"

  describe "GET /images/reports" do
    test "sin token responde 401", %{conn: conn} do
      conn = get(conn, ~p"/images/reports")

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "un usuario normal recibe 403", %{conn: conn} do
      token = registrar(conn, "ana.rios")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/images/reports")

      assert %{"error" => mensaje} = json_response(conn, 403)
      assert mensaje =~ "administrador"
    end

    test "un admin ve los reportes con su foto y con quien los abrió", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")

      imagen = crear_foto("moderador")
      reporte = crear_reporte(imagen, "moderador")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/images/reports")

      assert %{"reportes" => [fila]} = json_response(conn, 200)

      assert fila["id"] == reporte.id
      assert fila["motivo"] == "no_es_ave"
      assert fila["detalle"] == "No es un ave"
      assert fila["estado"] == "abierto"
      assert fila["reportado_por"] == "moderador"
      assert fila["avistamiento"]["id"] == imagen.id
      assert fila["avistamiento"]["url"] == imagen.url
    end

    test "vacío o `todos` deja el listado completo", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")
      crear_reporte(crear_foto("moderador"), "moderador")

      for filtro <- [nil, "", "todos"] do
        ruta = if filtro, do: ~p"/images/reports?estado=#{filtro}", else: ~p"/images/reports"

        conn =
          conn
          |> put_req_header("authorization", "Bearer #{token}")
          |> get(ruta)

        assert %{"reportes" => [_]} = json_response(conn, 200)
      end
    end

    test "`?estado=` filtra, y un estado desconocido da 400", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")
      crear_reporte(crear_foto("moderador"), "moderador")

      pedir = fn ruta ->
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(ruta)
      end

      assert %{"reportes" => [_]} = json_response(pedir.(~p"/images/reports?estado=abierto"), 200)
      assert %{"reportes" => []} = json_response(pedir.(~p"/images/reports?estado=revisado"), 200)
      assert %{"error" => _} = json_response(pedir.(~p"/images/reports?estado=zzz"), 400)
    end
  end

  describe "PUT /images/reports/:id" do
    test "un admin mueve un reporte de abierto a revisado", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")
      reporte = crear_reporte(crear_foto("moderador"), "moderador")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/images/reports/#{reporte.id}", %{"estado" => "revisado"})

      assert %{"id" => id, "estado" => estado} = json_response(conn, 200)
      assert id == reporte.id
      assert estado == "revisado"
    end

    test "un usuario normal recibe 403 y no cambia nada", %{conn: conn} do
      token = registrar(conn, "ana.rios")
      reporte = crear_reporte(crear_foto("ana.rios"), "ana.rios")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/images/reports/#{reporte.id}", %{"estado" => "revisado"})

      assert %{"error" => _} = json_response(conn, 403)

      assert {:ok, %Report{estado: :abierto}} = Ash.get(Report, reporte.id, authorize?: false)
    end

    test "un reporte inexistente da 404", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/images/reports/#{Ecto.UUID.generate()}", %{"estado" => "revisado"})

      assert %{"error" => _} = json_response(conn, 404)
    end

    test "un estado desconocido o ausente da 400", %{conn: conn} do
      token = registrar(conn, "moderador")
      ascender_a_admin("moderador")
      reporte = crear_reporte(crear_foto("moderador"), "moderador")

      pedir = fn cuerpo ->
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> put(~p"/images/reports/#{reporte.id}", cuerpo)
      end

      assert %{"error" => _} = json_response(pedir.(%{"estado" => "inventado"}), 400)
      assert %{"error" => _} = json_response(pedir.(%{}), 400)
    end
  end

  # --- Montaje --------------------------------------------------------------

  # Registra un usuario y devuelve su bearer token.
  defp registrar(conn, user) do
    conn
    |> post(~p"/api/user/signin", %{
      "user" => user,
      "password" => @password,
      "password_confirmation" => @password
    })
    |> json_response(201)
    |> Map.fetch!("token")
  end

  # El registro no acepta `rol`, así que se asciende con el mismo SQL crudo
  # que usan `priv/repo/seeds.exs`.
  defp ascender_a_admin(user) do
    Aves.Repo.query!("UPDATE users SET rol = 'admin' WHERE username = $1", [user])
  end

  defp usuario_id(user) do
    [[id]] = Aves.Repo.query!("SELECT id FROM users WHERE username = $1", [user]).rows
    id
  end

  defp crear_foto(user) do
    attrs = %{
      ruta: "uploads/reportes.png",
      url: "http://127.0.0.1:4001/uploads/reportes.png",
      categoria: "Ave",
      mime: "image/png",
      tamano: 78,
      autor_id: usuario_id(user),
      autor_nombre: user
    }

    {:ok, imagen} = Ash.create(Image, attrs, authorize?: false)
    imagen
  end

  defp crear_reporte(imagen, user) do
    attrs = %{
      avistamiento_id: imagen.id,
      reportado_por_id: usuario_id(user),
      motivo: :no_es_ave,
      detalle: "No es un ave"
    }

    {:ok, reporte} = Ash.create(Report, attrs, authorize?: false)
    reporte
  end
end
