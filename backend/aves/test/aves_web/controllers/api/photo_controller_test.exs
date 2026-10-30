defmodule AvesWeb.API.PhotoControllerTest do
  @moduledoc """
  Request tests for the public photo feed (RF-11).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

  describe "GET /api/photos (RF-11)" do
    test "devuelve fotos de otros usuarios, no las propias", %{conn: conn} do
      {viewer, token} = user_with_token()
      {other, _} = user_with_token()

      mine = sighting(viewer, %{place: "Mía"})
      theirs = sighting(other, %{place: "Ajena"})

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/photos")

      assert %{"photos" => photos} = json_response(conn, 200)
      ids = Enum.map(photos, & &1["id"])

      assert theirs.id in ids
      refute mine.id in ids
    end

    test "excluye avistamientos ocultos por moderación", %{conn: conn} do
      {_viewer, token} = user_with_token()
      {other, _} = user_with_token()
      sighting(other, %{place: "Oculta", hidden_at: DateTime.utc_now()})

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/photos")

      assert %{"photos" => []} = json_response(conn, 200)
    end

    test "filtra por bird_id", %{conn: conn} do
      {_viewer, token} = user_with_token()
      {other, _} = user_with_token()

      bird = bird()
      wanted = sighting(other, %{bird_id: bird.id, place: "Con ave"})
      _other = sighting(other, %{place: "Sin ave"})

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/photos?bird_id=#{wanted.bird_id}")

      assert %{"photos" => photos} = json_response(conn, 200)
      assert length(photos) == 1
      assert hd(photos)["bird_id"] == bird.id
    end

    test "filtra por category_id", %{conn: conn} do
      {_viewer, token} = user_with_token()
      {other, _} = user_with_token()

      category = category()
      bird = bird(%{category_id: category.id})
      _wanted = sighting(other, %{bird_id: bird.id})
      _noise = sighting(other)

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/photos?category_id=#{category.id}")

      assert %{"photos" => photos} = json_response(conn, 200)
      assert length(photos) == 1
    end

    test "sin token devuelve 401", %{conn: conn} do
      conn = get(conn, ~p"/api/photos")
      assert %{"error" => _} = json_response(conn, 401)
    end
  end
end
