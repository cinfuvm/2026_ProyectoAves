defmodule AvesWeb.ReportJSON do
  alias Aves.Moderation.Report

  @doc """
  Renders a list of reporte.
  """
  def index(%{reporte: reporte}) do
    %{data: for(report <- reporte, do: data(report))}
  end

  @doc """
  Renders a single report.
  """
  def show(%{report: report}) do
    %{data: data(report)}
  end

  defp data(%Report{} = report) do
    %{
      id: report.id,
      motivo: report.motivo,
      fecha_reporte: report.fecha_reporte
    }
  end
end
