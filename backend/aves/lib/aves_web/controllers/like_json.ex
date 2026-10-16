defmodule AvesWeb.LikeJSON do
  alias Aves.Social.Like

  @doc """
  Renders a list of like.
  """
  def index(%{like: like}) do
    %{data: for(like <- like, do: data(like))}
  end

  @doc """
  Renders a single like.
  """
  def show(%{like: like}) do
    %{data: data(like)}
  end

  defp data(%Like{} = like) do
    %{
      id: like.id,
      fecha_like: like.fecha_like
    }
  end
end
