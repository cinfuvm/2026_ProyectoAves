defmodule Mix.Tasks.Aves.CreateAdmin do
  @shortdoc "Crea o promueve un usuario a administrador"

  @moduledoc """
  Crea un usuario administrador, o promueve a `:admin` uno ya existente.

  Sirve para generar el **primer** administrador del sistema (bootstrap), ya que
  la lógica de roles no permite crear admins cuando aún no existe ninguno.

  ## Uso

      mix aves.create_admin EMAIL NICKNAME PASSWORD

  Si el email ya está registrado, solo se le asigna el rol `admin` (el nickname
  y el password se ignoran en ese caso).
  """
  use Mix.Task

  @impl Mix.Task
  def run([email, nickname, password]) do
    Mix.Task.run("app.start")

    case Aves.Accounts.create_admin(%{email: email, nickname: nickname, password: password}) do
      {:ok, user} ->
        Mix.shell().info("Administrador listo: #{user.email} (#{user.nickname})")

      {:error, error} ->
        Mix.raise("No se pudo crear el administrador: #{Exception.message(error)}")
    end
  end

  def run(_args) do
    Mix.raise("Uso: mix aves.create_admin EMAIL NICKNAME PASSWORD")
  end
end
