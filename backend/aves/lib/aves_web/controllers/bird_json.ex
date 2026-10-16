defmodule AvesWeb.BirdJSON do
  alias Aves.Catalog.Bird

  @doc """
  Renders a list of ave.
  """
  def index(%{ave: ave}) do
    %{data: for(bird <- ave, do: data(bird))}
  end

  @doc """
  Renders a single bird.
  """
  def show(%{bird: bird}) do
    %{data: data(bird)}
  end

  defp data(%Bird{} = bird) do
    %{
      id: bird.id,
      nombre_comun: bird.nombre_comun,
      nombre_cientifico: bird.nombre_cientifico
    }
  end
end
