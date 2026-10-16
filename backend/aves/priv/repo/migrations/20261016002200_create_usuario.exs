defmodule Aves.Repo.Migrations.CreateUsuario do
  use Ecto.Migration

  def change do
    create table(:usuario) do
      add :nickname, :string
      add :email, :string
      add :password_hash, :string
      add :rol, :string

      timestamps(type: :utc_datetime)
    end
  end
end
