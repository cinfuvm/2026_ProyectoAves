defmodule Aves.Repo.Migrations.CreatePublicacion do
  use Ecto.Migration

  def change do
    create table(:publicacion) do
      add :url_imagen, :string
      add :pie_de_foto, :string
      add :views_count, :integer
      add :fecha_creacion, :utc_datetime
      add :id_usuario, references(:usuario, on_delete: :nothing)
      add :id_ave, references(:ave, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:publicacion, [:id_usuario])
    create index(:publicacion, [:id_ave])
  end
end
