defmodule AvesWeb.PostController do
  use AvesWeb, :controller

  alias Aves.Social
  alias Aves.Social.Post

  action_fallback AvesWeb.FallbackController

  def index(conn, _params) do
    publicacion = Social.list_publicacion()
    render(conn, :index, publicacion: publicacion)
  end

  def create(conn, %{"post" => post_params}) do
    with {:ok, %Post{} = post} <- Social.create_post(post_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/publicacion/#{post}")
      |> render(:show, post: post)
    end
  end

  def show(conn, %{"id" => id}) do
    post = Social.get_post!(id)
    render(conn, :show, post: post)
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    post = Social.get_post!(id)

    with {:ok, %Post{} = post} <- Social.update_post(post, post_params) do
      render(conn, :show, post: post)
    end
  end

  def delete(conn, %{"id" => id}) do
    post = Social.get_post!(id)

    with {:ok, %Post{}} <- Social.delete_post(post) do
      send_resp(conn, :no_content, "")
    end
  end
end
