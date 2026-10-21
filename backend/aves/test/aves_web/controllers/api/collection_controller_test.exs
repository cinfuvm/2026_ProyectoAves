defmodule AvesWeb.API.CollectionControllerTest do
  @moduledoc """
  Request tests for the personal collection (RF-12).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

  alias Aves.Bitacora.CollectionItem

  describe "POST /api/collection (RF-12)" do
    test "agrega un avistamiento a la colección propia", %{conn: conn} do
      {user, token} = user_with_token()
      {other, _} = user_with_token()
      sighting = sighting(other)

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/collection", %{"sighting_id" => sighting.id})

      assert %{"item" => item} = json_response(conn, 201)
      assert item["sighting_id"] == sighting.id

      assert [%CollectionItem{owner_id: owner_id}] =
               Ash.read!(CollectionItem, authorize?: false)

      assert owner_id == user.id
    end

    test "evita duplicados del mismo avistamiento (identidad única)", %{conn: conn} do
      {_user, token} = user_with_token()
      {other, _} = user_with_token()
      sighting = sighting(other)

      conn |> sign_in_conn(token) |> post(~p"/api/collection", %{"sighting_id" => sighting.id})

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/collection", %{"sighting_id" => sighting.id})

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "sin token devuelve 401", %{conn: conn} do
      conn = post(conn, ~p"/api/collection", %{"sighting_id" => Ecto.UUID.generate()})
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "GET /api/collection (RF-12)" do
    test "devuelve solo los elementos del actor autenticado", %{conn: conn} do
      {user, token} = user_with_token()
      {other, _} = user_with_token()
      mine_sighting = sighting(other)
      theirs_sighting = sighting(user)

      {:ok, _} =
        Ash.create(CollectionItem, %{sighting_id: mine_sighting.id},
          actor: user,
          action: :add
        )

      {:ok, _} =
        Ash.create(CollectionItem, %{sighting_id: theirs_sighting.id},
          actor: other,
          action: :add
        )

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/collection")

      assert %{"items" => items} = json_response(conn, 200)
      assert length(items) == 1
      assert hd(items)["sighting_id"] == mine_sighting.id
    end
  end

  describe "DELETE /api/collection/:id (RF-12)" do
    test "elimina un elemento propio de la colección", %{conn: conn} do
      {user, token} = user_with_token()
      {other, _} = user_with_token()
      sighting = sighting(other)

      {:ok, item} =
        Ash.create(CollectionItem, %{sighting_id: sighting.id}, actor: user, action: :add)

      conn =
        conn
        |> sign_in_conn(token)
        |> delete(~p"/api/collection/#{item.id}")

      assert response(conn, 204)
      assert Ash.read!(CollectionItem, authorize?: false) == []
    end

    test "no permite eliminar un elemento de otro usuario", %{conn: conn} do
      {_user, token} = user_with_token()
      {other, _} = user_with_token()
      sighting = sighting(other)

      {:ok, foreign} =
        Ash.create(CollectionItem, %{sighting_id: sighting.id}, actor: other, action: :add)

      conn =
        conn
        |> sign_in_conn(token)
        |> delete(~p"/api/collection/#{foreign.id}")

      assert json_response(conn, 404)
      assert length(Ash.read!(CollectionItem, authorize?: false)) == 1
    end
  end
end
