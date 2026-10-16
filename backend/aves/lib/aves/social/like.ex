defmodule Aves.Social.Like do
  use Ecto.Schema
  import Ecto.Changeset

  schema "like" do
    field :fecha_like, :utc_datetime
    field :id_usuario, :id
    field :id_publicacion, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:fecha_like])
    |> validate_required([:fecha_like])
  end
end
