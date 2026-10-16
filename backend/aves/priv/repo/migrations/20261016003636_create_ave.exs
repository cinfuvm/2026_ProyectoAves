defmodule Aves.Repo.Migrations.CreateAve do
  use Ecto.Migration

  def change do
    create table(:ave) do
      add :nombre_comun, :string
      add :nombre_cientifico, :string

      timestamps(type: :utc_datetime)
    end
  end
end
