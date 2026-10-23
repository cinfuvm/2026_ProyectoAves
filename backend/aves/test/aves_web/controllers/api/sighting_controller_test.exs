defmodule AvesWeb.API.SightingControllerTest do
  @moduledoc """
  Request tests for the sightings endpoints (RF-08, RF-09, RF-10).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

  alias Aves.Storage

  @valid_attrs %{
    "place" => "Reserva Costanera",
    "spotted_on" => "2026-01-15",
    "comment" => "Un flamenco",
    "photo_url" => "https://example.com/flamenco.jpg"
  }

  describe "POST /api/sightings (RF-08)" do
    test "registra un avistamiento válido y devuelve 201", %{conn: conn} do
      {_user, token} = user_with_token()

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/sightings", @valid_attrs)

      assert %{"sighting" => sighting} = json_response(conn, 201)
      assert sighting["place"] == "Reserva Costanera"
      assert sighting["spotted_on"] == "2026-01-15"
      assert sighting["photo_url"] == "https://example.com/flamenco.jpg"
    end

    test "rechaza foto con extensión no permitida con 422", %{conn: conn} do
      {_user, token} = user_with_token()
      attrs = Map.put(@valid_attrs, "photo_url", "https://example.com/doc.pdf")

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/sightings", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors != []
    end

    test "exige el campo place con 422", %{conn: conn} do
      {_user, token} = user_with_token()
      attrs = Map.delete(@valid_attrs, "place")

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/sightings", attrs)

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "sin token devuelve 401", %{conn: conn} do
      conn = post(conn, ~p"/api/sightings", @valid_attrs)
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "fotos subidas (RF-08)" do
    setup context do
      previous = Application.get_env(:aves, :uploads_dir)
      Application.put_env(:aves, :uploads_dir, Path.join(context.tmp_dir, "uploads"))

      on_exit(fn -> Application.put_env(:aves, :uploads_dir, previous) end)
      :ok
    end

    @tag :tmp_dir
    test "guarda la foto en la carpeta pública y devuelve su URL", %{conn: conn, tmp_dir: tmp_dir} do
      {_user, token} = user_with_token()
      upload = jpeg_upload(tmp_dir)

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/sightings", Map.put(@valid_attrs, "photo", upload))

      assert %{"sighting" => sighting} = json_response(conn, 201)
      base = Application.fetch_env!(:aves, :public_base_url)
      assert sighting["photo_url"] =~ ~r|^#{Regex.escape(base)}/uploads/[0-9a-f-]{36}\.jpg$|

      stored = Path.join(Storage.uploads_dir(), Path.basename(sighting["photo_url"]))
      assert File.read!(stored) == File.read!(upload.path)

      # The database keeps the path only; the URL is completed in the response.
      saved = Ash.get!(Aves.Bitacora.Sighting, sighting["id"], authorize?: false)
      assert saved.photo_url =~ ~r|^/uploads/|
    end

    @tag :tmp_dir
    test "cada foto recibe un nombre distinto", %{conn: conn, tmp_dir: tmp_dir} do
      {_user, token} = user_with_token()
      params = Map.put(@valid_attrs, "photo", jpeg_upload(tmp_dir))

      first = conn |> sign_in_conn(token) |> post(~p"/api/sightings", params)
      second = conn |> sign_in_conn(token) |> post(~p"/api/sightings", params)

      assert json_response(first, 201)["sighting"]["photo_url"] !=
               json_response(second, 201)["sighting"]["photo_url"]
    end

    @tag :tmp_dir
    test "rechaza un archivo que no es JPEG ni PNG aunque tenga extensión .jpg", %{
      conn: conn,
      tmp_dir: tmp_dir
    } do
      {_user, token} = user_with_token()
      path = Path.join(tmp_dir, "nota.jpg")
      File.write!(path, "esto es texto, no una imagen")
      upload = %Plug.Upload{path: path, filename: "nota.jpg", content_type: "image/jpeg"}

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/sightings", Map.put(@valid_attrs, "photo", upload))

      assert %{"error" => message} = json_response(conn, 422)
      assert message =~ "JPEG o PNG"
    end

    @tag :tmp_dir
    test "PATCH reemplaza la foto por una subida", %{conn: conn, tmp_dir: tmp_dir} do
      {owner, token} = user_with_token()
      sighting = sighting(owner, %{photo_url: "https://example.com/vieja.jpg"})

      conn =
        conn
        |> sign_in_conn(token)
        |> patch(~p"/api/sightings/#{sighting.id}", %{"photo" => jpeg_upload(tmp_dir)})

      assert %{"sighting" => updated} = json_response(conn, 200)
      assert updated["photo_url"] =~ ~r|/uploads/.+\.jpg$|
    end

    @tag :tmp_dir
    test "si la base rechaza el avistamiento, la foto subida no queda en disco", %{
      conn: conn,
      tmp_dir: tmp_dir
    } do
      {_user, token} = user_with_token()
      attrs = @valid_attrs |> Map.delete("place") |> Map.put("photo", jpeg_upload(tmp_dir))

      conn = conn |> sign_in_conn(token) |> post(~p"/api/sightings", attrs)

      assert json_response(conn, 422)
      assert File.ls!(Storage.uploads_dir()) == []
    end

    @tag :tmp_dir
    test "eliminar el avistamiento borra su foto del disco", %{conn: conn} do
      {owner, token} = user_with_token()
      path = stored_photo!()
      sighting = sighting(owner, %{photo_url: "/uploads/" <> Path.basename(path)})

      conn = conn |> sign_in_conn(token) |> delete(~p"/api/sightings/#{sighting.id}")

      assert response(conn, 204)
      refute File.exists?(path)
    end

    @tag :tmp_dir
    test "PATCH con foto nueva borra la foto anterior", %{conn: conn, tmp_dir: tmp_dir} do
      {owner, token} = user_with_token()
      old = stored_photo!()
      sighting = sighting(owner, %{photo_url: "/uploads/" <> Path.basename(old)})

      conn =
        conn
        |> sign_in_conn(token)
        |> patch(~p"/api/sightings/#{sighting.id}", %{"photo" => jpeg_upload(tmp_dir)})

      assert json_response(conn, 200)
      refute File.exists?(old)
    end

    @tag :tmp_dir
    test "un PATCH rechazado conserva la foto anterior", %{conn: conn, tmp_dir: tmp_dir} do
      {owner, token} = user_with_token()
      old = stored_photo!()
      sighting = sighting(owner, %{photo_url: "/uploads/" <> Path.basename(old)})

      conn =
        conn
        |> sign_in_conn(token)
        |> patch(~p"/api/sightings/#{sighting.id}", %{
          "photo" => jpeg_upload(tmp_dir),
          "place" => nil
        })

      assert json_response(conn, 422)
      assert File.exists?(old)
      assert Storage.uploads_dir() |> File.ls!() |> length() == 1
    end
  end

  defp stored_photo! do
    File.mkdir_p!(Storage.uploads_dir())
    path = Path.join(Storage.uploads_dir(), "#{Ecto.UUID.generate()}.jpg")
    File.write!(path, "foto de prueba")
    path
  end

  defp jpeg_upload(dir) do
    path = Path.join(dir, "ave.jpg")
    File.write!(path, jpeg_bytes())
    %Plug.Upload{path: path, filename: "ave.jpg", content_type: "image/jpeg"}
  end

  describe "GET /api/sightings (RF-10)" do
    test "devuelve solo los avistamientos del actor, paginados", %{conn: conn} do
      {user, token} = user_with_token()
      {other, _} = user_with_token()

      sighting(user, %{place: "Mío"})
      sighting(other, %{place: "Ajeno"})

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/sightings")

      assert %{"sightings" => sightings, "pagination" => pagination} = json_response(conn, 200)
      assert length(sightings) == 1
      assert hd(sightings)["place"] == "Mío"
      assert pagination["page"] == 1
      assert pagination["count"] == 1
    end

    test "respeta el tamaño de página", %{conn: conn} do
      {user, token} = user_with_token()
      for _ <- 1..3, do: sighting(user)

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/sightings?page=1&per_page=2")

      assert %{"sightings" => sightings, "pagination" => pagination} = json_response(conn, 200)
      assert length(sightings) == 2
      assert pagination["per_page"] == 2
      assert pagination["count"] == 3
      assert pagination["more?"] == true
    end

    test "no incluye avistamientos eliminados lógicamente", %{conn: conn} do
      {user, token} = user_with_token()
      deleted = sighting(user, %{place: "Borrado"})

      {:ok, _} = Ash.update(deleted, %{}, action: :soft_delete, actor: user)

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/sightings")

      assert %{"sightings" => []} = json_response(conn, 200)
    end
  end

  describe "PATCH /api/sightings/:id (RF-09)" do
    test "edita un avistamiento propio", %{conn: conn} do
      {user, token} = user_with_token()
      sighting = sighting(user)

      conn =
        conn
        |> sign_in_conn(token)
        |> patch(~p"/api/sightings/#{sighting.id}", %{"place" => "Nuevo lugar"})

      assert %{"sighting" => updated} = json_response(conn, 200)
      assert updated["place"] == "Nuevo lugar"
    end

    test "no permite editar el avistamiento de otro usuario", %{conn: conn} do
      {_user, token} = user_with_token()
      {other, _} = user_with_token()
      foreign = sighting(other)

      conn =
        conn
        |> sign_in_conn(token)
        |> patch(~p"/api/sightings/#{foreign.id}", %{"place" => "Hackeado"})

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/sightings/:id (RF-09)" do
    test "elimina lógicamente un avistamiento propio", %{conn: conn} do
      {user, token} = user_with_token()
      sighting = sighting(user)

      conn =
        conn
        |> sign_in_conn(token)
        |> delete(~p"/api/sightings/#{sighting.id}")

      assert response(conn, 204)

      reloaded = Ash.get!(Aves.Bitacora.Sighting, sighting.id, authorize?: false)
      refute is_nil(reloaded.deleted_at)
    end

    test "no permite eliminar el avistamiento de otro usuario", %{conn: conn} do
      {_user, token} = user_with_token()
      {other, _} = user_with_token()
      foreign = sighting(other)

      conn =
        conn
        |> sign_in_conn(token)
        |> delete(~p"/api/sightings/#{foreign.id}")

      assert json_response(conn, 404)
    end
  end
end
