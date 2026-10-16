defmodule AvesWeb.ReportControllerTest do
  use AvesWeb.ConnCase

  import Aves.ModerationFixtures
  alias Aves.Moderation.Report

  @create_attrs %{
    motivo: "some motivo",
    fecha_reporte: ~U[2026-10-15 04:06:00Z]
  }
  @update_attrs %{
    motivo: "some updated motivo",
    fecha_reporte: ~U[2026-10-16 04:06:00Z]
  }
  @invalid_attrs %{motivo: nil, fecha_reporte: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all reporte", %{conn: conn} do
      conn = get(conn, ~p"/api/reporte")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create report" do
    test "renders report when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/reporte", report: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/reporte/#{id}")

      assert %{
               "id" => ^id,
               "fecha_reporte" => "2026-10-15T04:06:00Z",
               "motivo" => "some motivo"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/reporte", report: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update report" do
    setup [:create_report]

    test "renders report when data is valid", %{conn: conn, report: %Report{id: id} = report} do
      conn = put(conn, ~p"/api/reporte/#{report}", report: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/reporte/#{id}")

      assert %{
               "id" => ^id,
               "fecha_reporte" => "2026-10-16T04:06:00Z",
               "motivo" => "some updated motivo"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, report: report} do
      conn = put(conn, ~p"/api/reporte/#{report}", report: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete report" do
    setup [:create_report]

    test "deletes chosen report", %{conn: conn, report: report} do
      conn = delete(conn, ~p"/api/reporte/#{report}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reporte/#{report}")
      end
    end
  end

  defp create_report(_) do
    report = report_fixture()

    %{report: report}
  end
end
