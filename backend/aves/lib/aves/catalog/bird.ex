defmodule Aves.Catalog.Bird do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id_ave, :id, autogenerate: true}

  schema "ave" do
    field :nombre_comun, :string
    field :nombre_cientifico, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bird, attrs) do
    bird
    |> cast(attrs, [:nombre_comun, :nombre_cientifico])
    |> validate_required([:nombre_comun, :nombre_cientifico])
    |> unique_constraint(:nombre_cientifico)
  end
end
