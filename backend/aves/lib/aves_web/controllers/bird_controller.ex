defmodule AvesWeb.BirdController do
  use AvesWeb, :controller

  alias Aves.Catalog
  alias Aves.Catalog.Bird

  action_fallback AvesWeb.FallbackController

  def index(conn, _params) do
    ave = Catalog.list_ave()
    render(conn, :index, ave: ave)
  end

  def create(conn, %{"bird" => bird_params}) do
    with {:ok, %Bird{} = bird} <- Catalog.create_bird(bird_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/ave/#{bird}")
      |> render(:show, bird: bird)
    end
  end

  def show(conn, %{"id" => id}) do
    bird = Catalog.get_bird!(id)
    render(conn, :show, bird: bird)
  end

  def update(conn, %{"id" => id, "bird" => bird_params}) do
    bird = Catalog.get_bird!(id)

    with {:ok, %Bird{} = bird} <- Catalog.update_bird(bird, bird_params) do
      render(conn, :show, bird: bird)
    end
  end

  def delete(conn, %{"id" => id}) do
    bird = Catalog.get_bird!(id)

    with {:ok, %Bird{}} <- Catalog.delete_bird(bird) do
      send_resp(conn, :no_content, "")
    end
  end
end
