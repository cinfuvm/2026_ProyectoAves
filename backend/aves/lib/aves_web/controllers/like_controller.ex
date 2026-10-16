defmodule AvesWeb.LikeController do
  use AvesWeb, :controller

  alias Aves.Social
  alias Aves.Social.Like

  action_fallback AvesWeb.FallbackController

  def index(conn, _params) do
    like = Social.list_like()
    render(conn, :index, like: like)
  end

  def create(conn, %{"like" => like_params}) do
    with {:ok, %Like{} = like} <- Social.create_like(like_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/like/#{like}")
      |> render(:show, like: like)
    end
  end

  def show(conn, %{"id" => id}) do
    like = Social.get_like!(id)
    render(conn, :show, like: like)
  end

  def update(conn, %{"id" => id, "like" => like_params}) do
    like = Social.get_like!(id)

    with {:ok, %Like{} = like} <- Social.update_like(like, like_params) do
      render(conn, :show, like: like)
    end
  end

  def delete(conn, %{"id" => id}) do
    like = Social.get_like!(id)

    with {:ok, %Like{}} <- Social.delete_like(like) do
      send_resp(conn, :no_content, "")
    end
  end
end
