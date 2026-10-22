defmodule AvesWeb.API.BirdController do
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  require Ash.Query

  alias Aves.Catalog.Bird

  def index(conn, params) do
    query = Ash.Query.for_read(Bird, :read)

    query =
      case Map.get(params, "name") do
        name when is_binary(name) and name != "" ->
          pattern = "%#{name}%"
          Ash.Query.filter(query, ilike(name, ^pattern))

        _ ->
          query
      end

    query =
      case Map.get(params, "category_id") do
        category_id when is_binary(category_id) and category_id != "" ->
          Ash.Query.filter(query, category_id == ^category_id)

        _ ->
          query
      end

    query
    |> Ash.Query.load(:category)
    |> Ash.read(actor: actor(conn))
    |> case do
      {:ok, birds} ->
        json(conn, %{birds: Enum.map(birds, &bird_json/1)})

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, bird} <- fetch_bird(conn, id),
         {:ok, bird} <- Ash.load(bird, :category, actor: actor(conn)) do
      json(conn, %{bird: bird_json(bird)})
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Ave no encontrada")
    end
  end

  def create(conn, params) do
    attrs =
      %{}
      |> put_if(params, "name", :string)
      |> put_if(params, "category_id", :string)

    case Ash.create(Bird, attrs, actor: actor(conn), action: :create) do
      {:ok, bird} ->
        conn
        |> put_status(:created)
        |> json(%{bird: bird_json(bird)})

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, bird} <- fetch_bird(conn, id) do
      attrs =
        %{}
        |> put_if(params, "name", :string)
        |> put_if(params, "category_id", :string)

      case Ash.update(bird, attrs, actor: actor(conn), action: :update) do
        {:ok, updated_bird} ->
          json(conn, %{bird: bird_json(updated_bird)})

        {:error, error} ->
          error_response(conn, :unprocessable_entity, error)
      end
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Ave no encontrada")
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, bird} <- fetch_bird(conn, id),
         :ok <- Ash.destroy(bird, actor: actor(conn), action: :destroy) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Ave no encontrada")

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  defp fetch_bird(conn, id) do
    case Ash.get(Bird, id, actor: actor(conn)) do
      {:ok, %Bird{} = bird} -> {:ok, bird}
      _ -> {:error, :not_found}
    end
  end

  defp bird_json(bird) do
    %{
      id: bird.id,
      name: bird.name,
      category_id: bird.category_id,
      category:
        if(Ash.Resource.loaded?(bird, :category) and not is_nil(bird.category),
          do: %{id: bird.category.id, name: bird.category.name},
          else: nil
        ),
      inserted_at: bird.inserted_at,
      updated_at: bird.updated_at
    }
  end

  def ranking(conn, _params) do
    sql = """
    SELECT bird_id, COUNT(*) AS sightings_count
    FROM sightings
    WHERE bird_id IS NOT NULL
      AND deleted_at IS NULL
      AND hidden_at IS NULL
    GROUP BY bird_id
    ORDER BY COUNT(*) DESC, bird_id ASC
    """

    case Ecto.Adapters.SQL.query(Aves.Repo, sql, []) do
      {:ok, %{rows: []}} ->
        json(conn, %{birds: []})

      {:ok, %{rows: rows}} ->
        counts =
          Map.new(rows, fn [bird_id, count] ->
            {bird_id, count}
          end)

        bird_ids = Map.keys(counts)

        query =
          Ash.Query.for_read(Bird, :read)
          |> Ash.Query.filter(id in ^bird_ids)
          |> Ash.Query.load(:category)

        case Ash.read(query, actor: actor(conn)) do
          {:ok, birds} ->
            ranked_birds =
              birds
              |> Enum.sort_by(fn bird ->
                {
                  -Map.get(counts, bird.id, 0),
                  String.downcase(bird.name || "")
                }
              end)
              |> Enum.map(fn bird ->
                Map.put(
                  bird_json(bird),
                  :sightings_count,
                  Map.get(counts, bird.id, 0)
                )
              end)

            json(conn, %{birds: ranked_birds})

          {:error, error} ->
            error_response(conn, :forbidden, error)
        end

      {:error, error} ->
        error_response(conn, :internal_server_error, error)
    end
  end
end
