defmodule AvesWeb.UserJSON do
  alias Aves.Accounts.User

  @doc """
  Renders a list of usuario.
  """
  def index(%{usuario: usuario}) do
    %{data: for(user <- usuario, do: data(user))}
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      nickname: user.nickname,
      email: user.email,
      password_hash: user.password_hash,
      rol: user.rol
    }
  end
end
