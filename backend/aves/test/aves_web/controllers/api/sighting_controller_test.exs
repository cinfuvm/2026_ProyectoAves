defmodule AvesWeb.API.SightingControllerTest do
  @moduledoc """
  Request tests for the sightings endpoints (RF-08, RF-09, RF-10).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

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
