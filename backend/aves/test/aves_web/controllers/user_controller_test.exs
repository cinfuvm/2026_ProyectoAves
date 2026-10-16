defmodule AvesWeb.UserControllerTest do
  use AvesWeb.ConnCase

  import Aves.AccountsFixtures
  alias Aves.Accounts.User

  @create_attrs %{
    nickname: "some nickname",
    email: "some email",
    password_hash: "some password_hash",
    rol: "some rol"
  }
  @update_attrs %{
    nickname: "some updated nickname",
    email: "some updated email",
    password_hash: "some updated password_hash",
    rol: "some updated rol"
  }
  @invalid_attrs %{nickname: nil, email: nil, password_hash: nil, rol: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all usuario", %{conn: conn} do
      conn = get(conn, ~p"/api/usuario")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/usuario", user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/usuario/#{id}")

      assert %{
               "id" => ^id,
               "email" => "some email",
               "nickname" => "some nickname",
               "password_hash" => "some password_hash",
               "rol" => "some rol"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/usuario", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, ~p"/api/usuario/#{user}", user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/usuario/#{id}")

      assert %{
               "id" => ^id,
               "email" => "some updated email",
               "nickname" => "some updated nickname",
               "password_hash" => "some updated password_hash",
               "rol" => "some updated rol"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/api/usuario/#{user}", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/usuario/#{user}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/usuario/#{user}")
      end
    end
  end

  defp create_user(_) do
    user = user_fixture()

    %{user: user}
  end
end
