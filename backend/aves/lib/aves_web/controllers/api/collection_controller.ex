defmodule AvesWeb.API.CollectionController do
  @moduledoc """
  REST endpoints for the personal collection (RF-12): list, add and remove
  sightings saved by the authenticated actor. Authorization is enforced by the
  `Aves.Bitacora.CollectionItem` policies.
  """
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  alias Aves.Bitacora.CollectionItem

  @doc "GET /api/collection - List the actor's collection (RF-12)."
  def index(conn, _params) do
    CollectionItem
    |> Ash.Query.for_read(:read)
    |> Ash.Query.load(sighting: [:bird])
    |> Ash.read(actor: actor(conn))
    |> case do
      {:ok, items} ->
        json(conn, %{items: Enum.map(items, &collection_item_json/1)})

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  @doc "POST /api/collection - Add a sighting to the collection (RF-12)."
  def create(conn, params) do
    attrs = %{}
    |> put_if(params, "sighting_id", :string)

    case Ash.create(CollectionItem, attrs, actor: actor(conn), action: :add) do
      {:ok, item} ->
        conn
        |> put_status(:created)
        |> json(%{item: collection_item_json(item)})

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  @doc "DELETE /api/collection/:id - Remove an item from the collection (RF-12)."
  def delete(conn, %{"id" => id}) do
    with {:ok, item} <- fetch_item(conn, id),
         :ok <- Ash.destroy(item, actor: actor(conn)) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Elemento de colección no encontrado")

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  # --- helpers ---

  defp fetch_item(conn, id) do
    case Ash.get(CollectionItem, id, actor: actor(conn)) do
      {:ok, item} -> {:ok, item}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp collection_item_json(item) do
    %{
      id: item.id,
      sighting_id: item.sighting_id,
      owner_id: item.owner_id,
      inserted_at: item.inserted_at,
      sighting:
        if(Ash.Resource.loaded?(item, :sighting), do: sighting_json(item.sighting), else: nil)
    }
  end
end
