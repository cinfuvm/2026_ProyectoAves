defmodule AvesWeb.PostJSON do
  alias Aves.Social.Post

  @doc """
  Renders a list of publicacion.
  """
  def index(%{publicacion: publicacion}) do
    %{data: for(post <- publicacion, do: data(post))}
  end

  @doc """
  Renders a single post.
  """
  def show(%{post: post}) do
    %{data: data(post)}
  end

  defp data(%Post{} = post) do
    %{
      id: post.id,
      url_imagen: post.url_imagen,
      pie_de_foto: post.pie_de_foto,
      views_count: post.views_count,
      fecha_creacion: post.fecha_creacion
    }
  end
end
