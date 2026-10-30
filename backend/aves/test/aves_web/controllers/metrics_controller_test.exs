defmodule AvesWeb.MetricsControllerTest do
  @moduledoc """
  `GET /metrics` is behind basic auth and serves the Prometheus text format.
  """
  use AvesWeb.ConnCase

  defp basic(username, password), do: "Basic " <> Base.encode64("#{username}:#{password}")

  test "sin credenciales responde 401", %{conn: conn} do
    assert get(conn, ~p"/metrics").status == 401
  end

  test "con credenciales incorrectas responde 401", %{conn: conn} do
    conn = put_req_header(conn, "authorization", basic("otro", "incorrecta"))

    assert get(conn, ~p"/metrics").status == 401
  end

  test "con credenciales correctas devuelve las métricas de Prometheus", %{conn: conn} do
    credentials = Map.new(Application.fetch_env!(:aves, :metrics_auth))

    conn =
      put_req_header(conn, "authorization", basic(credentials.username, credentials.password))

    conn = get(conn, ~p"/metrics")

    assert conn.status == 200
    assert conn.resp_body =~ "aves_prom_ex_beam_stats_run_queue_count"
    assert conn.resp_body =~ "aves_prom_ex_phoenix_http_requests_total"
  end
end
