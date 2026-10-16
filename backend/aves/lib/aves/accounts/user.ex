defmodule Aves.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "usuario" do
    field :nickname, :string
    field :email, :string
    field :password_hash, :string
    field :rol, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname, :email, :password_hash, :rol])
    |> validate_required([:nickname, :email, :password_hash, :rol])
  end
end
