defmodule AvesWeb.API.CategoryController do
  use AvesWeb, :controller

  import AvesWeb.API.Helpers

  alias Aves.Catalog.Category

  def index(conn, _params) do
    Category
    |> Ash.Query.for_read(:read)
    |> Ash.read(actor: actor(conn))
    |> case do
      {:ok, categories} ->
        json(conn, %{categories: Enum.map(categories, &category_json/1)})

      {:error, error} ->
        error_response(conn, :forbidden, error)
    end
  end

  def create(conn, params) do
    attrs =
      %{}
      |> put_if(params, "name", :string)

    case Ash.create(Category, attrs, actor: actor(conn), action: :create) do
      {:ok, category} ->
        conn
        |> put_status(:created)
        |> json(%{category: category_json(category)})

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, category} <- fetch_category(conn, id) do
      attrs =
        %{}
        |> put_if(params, "name", :string)

      case Ash.update(category, attrs, actor: actor(conn), action: :update) do
        {:ok, updated_category} ->
          json(conn, %{category: category_json(updated_category)})

        {:error, error} ->
          error_response(conn, :unprocessable_entity, error)
      end
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Categoría no encontrada")
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, category} <- fetch_category(conn, id),
         :ok <- Ash.destroy(category, actor: actor(conn), action: :destroy) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        error_response(conn, :not_found, "Categoría no encontrada")

      {:error, error} ->
        error_response(conn, :unprocessable_entity, error)
    end
  end

  defp fetch_category(conn, id) do
    case Ash.get(Category, id, actor: actor(conn)) do
      {:ok, %Category{} = category} -> {:ok, category}
      _ -> {:error, :not_found}
    end
  end

  defp category_json(category) do
    %{
      id: category.id,
      name: category.name,
      inserted_at: category.inserted_at,
      updated_at: category.updated_at
    }
  end
end
