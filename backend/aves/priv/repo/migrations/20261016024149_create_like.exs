defmodule Aves.Repo.Migrations.CreateLike do
  use Ecto.Migration

  def change do
    create table(:like) do
      add :fecha_like, :utc_datetime
      add :id_usuario, references(:usuario, on_delete: :nothing)
      add :id_publicacion, references(:publicacion, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:like, [:id_usuario])
    create index(:like, [:id_publicacion])
  end
end
