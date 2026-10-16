defmodule AvesWeb.BirdControllerTest do
  use AvesWeb.ConnCase

  import Aves.CatalogFixtures
  alias Aves.Catalog.Bird

  @create_attrs %{
    nombre_comun: "some nombre_comun",
    nombre_cientifico: "some nombre_cientifico"
  }
  @update_attrs %{
    nombre_comun: "some updated nombre_comun",
    nombre_cientifico: "some updated nombre_cientifico"
  }
  @invalid_attrs %{nombre_comun: nil, nombre_cientifico: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all ave", %{conn: conn} do
      conn = get(conn, ~p"/api/ave")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create bird" do
    test "renders bird when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/ave", bird: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/ave/#{id}")

      assert %{
               "id" => ^id,
               "nombre_cientifico" => "some nombre_cientifico",
               "nombre_comun" => "some nombre_comun"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/ave", bird: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update bird" do
    setup [:create_bird]

    test "renders bird when data is valid", %{conn: conn, bird: %Bird{id: id} = bird} do
      conn = put(conn, ~p"/api/ave/#{bird}", bird: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/ave/#{id}")

      assert %{
               "id" => ^id,
               "nombre_cientifico" => "some updated nombre_cientifico",
               "nombre_comun" => "some updated nombre_comun"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, bird: bird} do
      conn = put(conn, ~p"/api/ave/#{bird}", bird: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete bird" do
    setup [:create_bird]

    test "deletes chosen bird", %{conn: conn, bird: bird} do
      conn = delete(conn, ~p"/api/ave/#{bird}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/ave/#{bird}")
      end
    end
  end

  defp create_bird(_) do
    bird = bird_fixture()

    %{bird: bird}
  end
end
