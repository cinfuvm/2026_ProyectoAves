defmodule AvesWeb.PostControllerTest do
  use AvesWeb.ConnCase

  import Aves.SocialFixtures
  alias Aves.Social.Post

  @create_attrs %{
    url_imagen: "some url_imagen",
    pie_de_foto: "some pie_de_foto",
    views_count: 42,
    fecha_creacion: ~U[2026-10-15 02:26:00Z]
  }
  @update_attrs %{
    url_imagen: "some updated url_imagen",
    pie_de_foto: "some updated pie_de_foto",
    views_count: 43,
    fecha_creacion: ~U[2026-10-16 02:26:00Z]
  }
  @invalid_attrs %{url_imagen: nil, pie_de_foto: nil, views_count: nil, fecha_creacion: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all publicacion", %{conn: conn} do
      conn = get(conn, ~p"/api/publicacion")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create post" do
    test "renders post when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/publicacion", post: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/publicacion/#{id}")

      assert %{
               "id" => ^id,
               "fecha_creacion" => "2026-10-15T02:26:00Z",
               "pie_de_foto" => "some pie_de_foto",
               "url_imagen" => "some url_imagen",
               "views_count" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/publicacion", post: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update post" do
    setup [:create_post]

    test "renders post when data is valid", %{conn: conn, post: %Post{id: id} = post} do
      conn = put(conn, ~p"/api/publicacion/#{post}", post: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/publicacion/#{id}")

      assert %{
               "id" => ^id,
               "fecha_creacion" => "2026-10-16T02:26:00Z",
               "pie_de_foto" => "some updated pie_de_foto",
               "url_imagen" => "some updated url_imagen",
               "views_count" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, post: post} do
      conn = put(conn, ~p"/api/publicacion/#{post}", post: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete post" do
    setup [:create_post]

    test "deletes chosen post", %{conn: conn, post: post} do
      conn = delete(conn, ~p"/api/publicacion/#{post}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/publicacion/#{post}")
      end
    end
  end

  defp create_post(_) do
    post = post_fixture()

    %{post: post}
  end
end
