defmodule AvesWeb.API.ReportController do
  @moduledoc """
  REST endpoints for reporting photos and the moderator queue.

  Covers:
    * RF-13 — report a photo that does not correspond to a bird.
    * RF-14 — moderator queue: list reports and approve/retire them.

  Authorization is enforced by the `Aves.Moderation.Report` policies. Retiring a
  report also hides the reported sighting (sets `hidden_at`).
  """
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  require Ash.Query

  alias Aves.Moderation.Report
  alias Aves.Bitacora.Sighting

  @doc "POST /api/reports - Report a photo (RF-13)."
  def create(conn, params) do
    attrs = %{}
    |> put_if(params, "sighting_id", :string)
    |> put_if(params, "reason", :string)

    case Ash.create(Report, attrs, actor: actor(conn), action: :report) do
      {:ok, report} ->
        conn
        |> put_status(:created)
        |> json(%{report: report_json(report)})

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  @doc "GET /api/reports - Moderator queue (RF-14)."
  def index(conn, params) do
    Report
    |> Ash.Query.for_read(:read)
    |> maybe_filter_status(params["status"])
    |> Ash.Query.load(sighting: [:bird])
    |> Ash.read(actor: actor(conn), page: page_opts(params))
    |> case do
      {:ok, page} ->
        json(conn, %{
          reports: Enum.map(page.results, &report_json/1),
          pagination: pagination_json(page)
        })

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  @doc "POST /api/reports/:id/approve - Approve report; photo stays visible (RF-14)."
  def approve(conn, %{"id" => id}) do
    case update_status(conn, id, :approve) do
      {:ok, report} -> json(conn, %{report: report_json(report)})
      {:error, conn} -> conn
    end
  end

  @doc "POST /api/reports/:id/retire - Retire report; hide the photo (RF-14)."
  def retire(conn, %{"id" => id}) do
    case update_status(conn, id, :retire) do
      {:ok, report} ->
        hide_sighting(conn, report)
        json(conn, %{report: report_json(report)})

      {:error, conn} ->
        conn
    end
  end

  # --- helpers ---

  # Returns `{:ok, report}` or `{:error, conn}` (already-sent error response).
  defp update_status(conn, id, action) do
    with {:ok, report} <- fetch_report(conn, id),
         {:ok, updated} <- Ash.update(report, %{}, actor: actor(conn), action: action) do
      {:ok, updated}
    else
      {:error, :not_found} ->
        {:error, error_response(conn, :not_found, "Reporte no encontrado")}

      {:error, %Ash.Error.Forbidden{} = error} ->
        {:error, error_response(conn, :forbidden, error)}

      {:error, error} ->
        {:error, error_response(conn, :unprocessable_entity, error)}
    end
  end

  defp hide_sighting(conn, report) do
    case Ash.get(Sighting, report.sighting_id, actor: actor(conn)) do
      {:ok, sighting} ->
        Ash.update(sighting, %{}, actor: actor(conn), action: :hide)

      _ ->
        :ok
    end
  end

  defp fetch_report(conn, id) do
    case Ash.get(Report, id, actor: actor(conn)) do
      {:ok, report} -> {:ok, report}
      {:error, %Ash.Error.Forbidden{} = error} -> {:error, error}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    status_atom = String.to_existing_atom(status)
    Ash.Query.filter(query, status == ^status_atom)
  end

  defp report_json(report) do
    %{
      id: report.id,
      sighting_id: report.sighting_id,
      reporter_id: report.reporter_id,
      reason: report.reason,
      status: report.status,
      inserted_at: report.inserted_at,
      sighting:
        if(Ash.Resource.loaded?(report, :sighting), do: sighting_json(report.sighting), else: nil)
    }
  end
end
<<<<<<< HEAD

=======
>>>>>>> feat/backend/marcelo
