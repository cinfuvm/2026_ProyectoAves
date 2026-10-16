defmodule Aves.Repo.Migrations.CreateReporte do
  use Ecto.Migration

  def change do
    create table(:reporte) do
      add :motivo, :string
      add :fecha_reporte, :utc_datetime
      add :id_usuario, references(:usuario, on_delete: :nothing)
      add :id_publicacion, references(:publicacion, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:reporte, [:id_usuario])
    create index(:reporte, [:id_publicacion])
  end
end
