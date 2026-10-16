defmodule AvesWeb.LikeControllerTest do
  use AvesWeb.ConnCase

  import Aves.SocialFixtures
  alias Aves.Social.Like

  @create_attrs %{
    fecha_like: ~U[2026-10-15 02:41:00Z]
  }
  @update_attrs %{
    fecha_like: ~U[2026-10-16 02:41:00Z]
  }
  @invalid_attrs %{fecha_like: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all like", %{conn: conn} do
      conn = get(conn, ~p"/api/like")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create like" do
    test "renders like when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/like", like: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/like/#{id}")

      assert %{
               "id" => ^id,
               "fecha_like" => "2026-10-15T02:41:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/like", like: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update like" do
    setup [:create_like]

    test "renders like when data is valid", %{conn: conn, like: %Like{id: id} = like} do
      conn = put(conn, ~p"/api/like/#{like}", like: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/like/#{id}")

      assert %{
               "id" => ^id,
               "fecha_like" => "2026-10-16T02:41:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, like: like} do
      conn = put(conn, ~p"/api/like/#{like}", like: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete like" do
    setup [:create_like]

    test "deletes chosen like", %{conn: conn, like: like} do
      conn = delete(conn, ~p"/api/like/#{like}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/like/#{like}")
      end
    end
  end

  defp create_like(_) do
    like = like_fixture()

    %{like: like}
  end
end
