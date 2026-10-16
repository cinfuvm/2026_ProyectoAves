defmodule Aves.Social.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publicacion" do
    field :url_imagen, :string
    field :pie_de_foto, :string
    field :views_count, :integer
    field :fecha_creacion, :utc_datetime
    field :id_usuario, :id
    field :id_ave, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:url_imagen, :pie_de_foto, :views_count, :fecha_creacion])
    |> validate_required([:url_imagen, :pie_de_foto, :views_count, :fecha_creacion])
  end
end
