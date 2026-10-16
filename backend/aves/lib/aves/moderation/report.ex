defmodule Aves.Moderation.Report do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reporte" do
    field :motivo, :string
    field :fecha_reporte, :utc_datetime
    field :id_usuario, :id
    field :id_publicacion, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [:motivo, :fecha_reporte])
    |> validate_required([:motivo, :fecha_reporte])
  end
end
