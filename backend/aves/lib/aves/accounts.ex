defmodule Aves.Accounts do
  @moduledoc """
  Dominio de cuentas: usuarios y tokens de autenticación.
  """
  use Ash.Domain,
    otp_app: :aves

  require Ash.Query

  alias Aves.Accounts.User

  resources do
    resource Aves.Accounts.Token
    resource Aves.Accounts.User
  end

  @doc """
  Crea un usuario administrador, o promueve a `:admin` uno existente.

  Se usa para generar el **primer** administrador (bootstrap), ya que ninguna
  política permite crear un admin cuando todavía no existe ninguno. La promoción
  se hace con `authorize?: false`, un bypass controlado que solo se invoca desde
  el task `mix aves.create_admin`.

  Acepta un mapa con `:email`, `:password` y, opcionalmente, `:nickname`.

  ## Ejemplo

      iex> Aves.Accounts.create_admin(%{
      ...>   email: "admin@example.com",
      ...>   nickname: "admin",
      ...>   password: "supersecret123"
      ...> })
      {:ok, %Aves.Accounts.User{}}
  """
  @spec create_admin(map()) :: {:ok, User.t()} | {:error, term()}
  def create_admin(%{email: email, password: password} = attrs) do
    params = %{
      "email" => email,
      "nickname" => Map.get(attrs, :nickname),
      "password" => password,
      "password_confirmation" => password
    }

    case register(params) do
      {:ok, user} ->
        promote(user)

      {:error, register_error} ->
        case fetch_by_email(email) do
          {:ok, nil} -> {:error, register_error}
          {:ok, user} -> promote(user)
          {:error, error} -> {:error, error}
        end
    end
  end

  defp register(params) do
    strategy = AshAuthentication.Info.strategy!(User, :password)
    AshAuthentication.Strategy.action(strategy, :register, params)
  end

  defp promote(user) do
    Ash.update(user, %{rol: :admin}, action: :assign_role, authorize?: false)
  end

  defp fetch_by_email(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one(authorize?: false)
  end
end
