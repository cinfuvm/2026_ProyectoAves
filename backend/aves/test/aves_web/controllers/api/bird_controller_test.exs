defmodule AvesWeb.API.BirdControllerTest do
  @moduledoc """
  Request tests for the bird catalog: search, detail (RF-07), view tracking
  and ranking of popular birds (RF-15).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

  require Ash.Query

  alias Aves.Catalog.BirdView

  defp seed_views(bird, count) do
    for _ <- 1..count//1 do
      BirdView |> Ash.Seed.seed!(%{bird_id: bird.id})
    end
  end

  defp views_of(bird) do
    BirdView
    |> Ash.Query.filter(bird_id == ^bird.id)
    |> Ash.count!(authorize?: false)
  end

  describe "GET /api/birds" do
    test "filtra por categoría", %{conn: conn} do
      {_user, token} = user_with_token()
      category = category()
      match = bird(%{category_id: category.id})
      bird(%{})

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/birds", %{"category_id" => category.id})

      assert [%{"id" => id}] = json_response(conn, 200)["birds"]
      assert id == match.id
    end

    test "rechaza un category_id que no es UUID con 422", %{conn: conn} do
      {_user, token} = user_with_token()

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/birds", %{"category_id" => "no-es-uuid"})

      assert %{"error" => message} = json_response(conn, 422)
      assert message =~ "UUID"
    end
  end

  describe "GET /api/birds/:id (RF-07)" do
    test "devuelve la ficha con su galería", %{conn: conn} do
      {_user, token} = user_with_token()
      {owner, _} = user_with_token()

      bird =
        bird(%{
          scientific_name: "Phoenicopterus chilensis",
          description: "Ave de gran tamaño"
        })

      sighting(owner, %{bird_id: bird.id})

      conn = conn |> sign_in_conn(token) |> get(~p"/api/birds/#{bird.id}")

      assert %{"bird" => json} = json_response(conn, 200)
      assert json["scientific_name"] == "Phoenicopterus chilensis"
      assert json["description"] == "Ave de gran tamaño"
      assert [_photo] = json["photos"]
    end

    test "registra una vista en bird_views", %{conn: conn} do
      {_user, token} = user_with_token()
      bird = bird(%{})

      conn |> sign_in_conn(token) |> get(~p"/api/birds/#{bird.id}")
      conn |> sign_in_conn(token) |> get(~p"/api/birds/#{bird.id}")

      assert views_of(bird) == 2
    end

    test "devuelve 404 para un ave inexistente", %{conn: conn} do
      {_user, token} = user_with_token()

      conn = conn |> sign_in_conn(token) |> get(~p"/api/birds/#{Ecto.UUID.generate()}")

      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "GET /api/birds/ranking (RF-15)" do
    test "ordena por vistas de mayor a menor", %{conn: conn} do
      {_user, token} = user_with_token()
      popular = bird(%{name: "Cisne de cuello negro"})
      other = bird(%{name: "Tiuque"})
      seed_views(popular, 3)
      seed_views(other, 1)

      conn = conn |> sign_in_conn(token) |> get(~p"/api/birds/ranking")

      assert %{"birds" => [first, second]} = json_response(conn, 200)
      assert first["id"] == popular.id
      assert first["views_count"] == 3
      assert second["id"] == other.id
      assert second["views_count"] == 1
    end
  end

  describe "DELETE /api/birds/:id" do
    test "elimina el ave junto con sus vistas", %{conn: conn} do
      {_admin, token} = user_with_token(:admin)
      bird = bird(%{})
      seed_views(bird, 2)

      conn = conn |> sign_in_conn(token) |> delete(~p"/api/birds/#{bird.id}")

      assert response(conn, 204)
      assert views_of(bird) == 0
    end
  end
end
