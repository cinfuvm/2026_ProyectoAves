defmodule AvesWeb.API.SightingController do
  @moduledoc """
  REST endpoints for personal sightings (bitácora).

  Covers:
    * RF-08 — register a sighting (place, date, comment and photo).
    * RF-09 — edit and (logically) delete own sightings.
    * RF-10 — personal (paginated) log.

  The authenticated user is taken from the Ash actor set by `AvesWeb.AuthPlug`;
  authorization is enforced by the `Aves.Bitacora.Sighting` policies.
  """
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  require Ash.Query

  alias Aves.Bitacora.Sighting

  @doc "POST /api/sightings - Register a sighting (RF-08)."
  def create(conn, params) do
    case Ash.create(Sighting, sighting_params(params),
           actor: actor(conn),
           action: :register
         ) do
      {:ok, sighting} ->
        conn
        |> put_status(:created)
        |> json(%{sighting: sighting_json(sighting)})

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  @doc "PATCH /api/sightings/:id - Edit an own sighting (RF-09)."
  def update(conn, %{"id" => id} = params) do
    with {:ok, sighting} <- fetch_sighting(conn, id),
         {:ok, updated} <-
           Ash.update(sighting, sighting_params(params), actor: actor(conn), action: :update) do
      json(conn, %{sighting: sighting_json(updated)})
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Avistamiento no encontrado")

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  @doc "DELETE /api/sightings/:id - Logically delete an own sighting (RF-09)."
  def delete(conn, %{"id" => id}) do
    with {:ok, sighting} <- fetch_sighting(conn, id),
         {:ok, _deleted} <- Ash.update(sighting, %{}, actor: actor(conn), action: :soft_delete) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Avistamiento no encontrado")

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  @doc "GET /api/sightings - Personal log, paginated (RF-10)."
  def index(conn, params) do
    Sighting
    |> Ash.Query.for_read(:personal_log)
    |> Ash.Query.load([:bird])
    |> Ash.read(actor: actor(conn), page: page_opts(params))
    |> case do
      {:ok, page} ->
        json(conn, %{
          sightings: Enum.map(page.results, &sighting_json/1),
          pagination: pagination_json(page)
        })

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  # --- helpers ---

  defp fetch_sighting(conn, id) do
    Sighting
    |> Ash.Query.for_read(:personal_log)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: actor(conn))
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, sighting} -> {:ok, sighting}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp sighting_params(params) do
    %{}
    |> put_if(params, "place", :string)
    |> put_if(params, "comment", :string)
    |> put_if(params, "photo_url", :string)
    |> put_if(params, "spotted_on", :date)
    |> put_if(params, "bird_id", :string)
  end
end

