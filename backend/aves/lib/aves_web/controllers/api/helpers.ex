defmodule AvesWeb.API.Helpers do
  @moduledoc """
  Shared helpers for the `AvesWeb.API.*` controllers: actor extraction, JSON
  serialization, pagination and error responses.

  Kept here so every API controller stays thin and DRY.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Ash.Page.Offset

  @default_per_page 20

  @doc "Returns the Ash actor (authenticated user) from the conn."
  def actor(conn), do: Ash.PlugHelpers.get_actor(conn)

  @doc "Builds `page`/`offset` options from query params (`page`, `per_page`)."
  def page_opts(params) do
    limit = parse_int(params["per_page"], @default_per_page)
    offset = (max(parse_int(params["page"], 1), 1) - 1) * limit
    [limit: limit, offset: offset, count: true]
  end

  @doc "Serializes an Ash offset page into a JSON-friendly map."
  def pagination_json(%Offset{} = page) do
    %{
      page: div(page.offset || 0, page.limit) + 1,
      per_page: page.limit,
      count: page.count,
      more?: page.more?
    }
  end

  @doc "Sends a JSON error response. Accepts a binary message or an Ash error."
  def error_response(conn, status, message) when is_binary(message) do
    conn |> put_status(status) |> json(%{error: message})
  end

  def error_response(conn, status, error) do
    conn |> put_status(status) |> json(%{errors: error_messages(error)})
  end

  @doc "Normalizes an error into a list of human-readable messages."
  def error_messages(error) do
    case error do
      %Ash.Error.Invalid{errors: errors} -> Enum.map(errors, &Exception.message/1)
      %Ash.Error.Forbidden{errors: errors} -> Enum.map(errors, &Exception.message/1)
      _ -> [Exception.message(error)]
    end
  end

  @doc "Serializes a `Sighting` resource into a JSON-friendly map."
  def sighting_json(sighting) do
    %{
      id: sighting.id,
      place: sighting.place,
      spotted_on: to_string(sighting.spotted_on),
      comment: sighting.comment,
      photo_url: sighting.photo_url,
      bird_id: sighting.bird_id,
      owner_id: sighting.owner_id,
      inserted_at: sighting.inserted_at
    }
  end

  @doc "Parses a positive integer from params, falling back to `default`."
  def parse_int(nil, default), do: default

  def parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  def parse_int(value, _default) when is_integer(value), do: value

  @doc "Puts `params[key]` into the changes map only when the key is present."
  def put_if(acc, params, key, _type) when is_map_key(params, key) do
    Map.put(acc, key, params[key])
  end

  def put_if(acc, _params, _key, _type), do: acc
end
