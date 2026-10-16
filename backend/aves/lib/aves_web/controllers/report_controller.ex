defmodule AvesWeb.ReportController do
  use AvesWeb, :controller

  alias Aves.Moderation
  alias Aves.Moderation.Report

  action_fallback AvesWeb.FallbackController

  def index(conn, _params) do
    reporte = Moderation.list_reporte()
    render(conn, :index, reporte: reporte)
  end

  def create(conn, %{"report" => report_params}) do
    with {:ok, %Report{} = report} <- Moderation.create_report(report_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/reporte/#{report}")
      |> render(:show, report: report)
    end
  end

  def show(conn, %{"id" => id}) do
    report = Moderation.get_report!(id)
    render(conn, :show, report: report)
  end

  def update(conn, %{"id" => id, "report" => report_params}) do
    report = Moderation.get_report!(id)

    with {:ok, %Report{} = report} <- Moderation.update_report(report, report_params) do
      render(conn, :show, report: report)
    end
  end

  def delete(conn, %{"id" => id}) do
    report = Moderation.get_report!(id)

    with {:ok, %Report{}} <- Moderation.delete_report(report) do
      send_resp(conn, :no_content, "")
    end
  end
end
