defmodule AvesWeb.API.PhotoController do
  @moduledoc """
  REST endpoint for browsing other users' photos (RF-11).

  Returns visible (non-hidden, non-deleted) sightings authored by users other
  than the actor, optionally filtered by bird or category. Authorization is
  enforced by the `Aves.Bitacora.Sighting` :public read policy.
  """
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  require Ash.Query

  alias Aves.Bitacora.Sighting

  @doc "GET /api/photos - Photos from other users, filterable (RF-11)."
  def index(conn, params) do
    Sighting
    |> Ash.Query.for_read(:public)
    |> Ash.Query.load([:bird])
    |> filter_bird(params["bird_id"])
    |> filter_category(params["category_id"])
    |> Ash.read(actor: actor(conn), page: page_opts(params))
    |> case do
      {:ok, page} ->
        json(conn, %{
          photos: Enum.map(page.results, &sighting_json/1),
          pagination: pagination_json(page)
        })

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  defp filter_bird(query, nil), do: query
  defp filter_bird(query, bird_id), do: Ash.Query.filter(query, bird_id == ^bird_id)

  defp filter_category(query, nil), do: query

  defp filter_category(query, category_id) do
    Ash.Query.filter(query, bird.category_id == ^category_id)
  end
end

