defmodule Aves.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Aves.Catalog` context.
  """

  @doc """
  Generate a bird.
  """
  def bird_fixture(attrs \\ %{}) do
    {:ok, bird} =
      attrs
      |> Enum.into(%{
        nombre_cientifico: "some nombre_cientifico",
        nombre_comun: "some nombre_comun"
      })
      |> Aves.Catalog.create_bird()

    bird
  end
end
