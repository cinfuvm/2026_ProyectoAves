defmodule AvesWeb.API.UserController do
  @moduledoc """
  Endpoints REST de autenticación para el cliente móvil.

  No reimplementan la lógica de autenticación: delegan en las acciones
  generadas por `AshAuthentication` (estrategia `:password` del recurso
  `Aves.Accounts.User`), de modo que el dashboard web también pueda reutilizar
  las mismas acciones.
  """
  use AvesWeb, :controller

  alias AshAuthentication.{Info, Strategy}
  alias Aves.Accounts.User

  @doc "POST /api/user/signin - Registra un usuario y devuelve un bearer token."
  def register(conn, params) do
    case Strategy.action(strategy(), :register, register_params(params)) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(auth_response(user))

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error_messages(error)})
    end
  end

  @doc "POST /api/user/login - Inicia sesión y devuelve un bearer token."
  def login(conn, params) do
    case Strategy.action(strategy(), :sign_in, sign_in_params(params)) do
      {:ok, user} ->
        json(conn, auth_response(user))

      {:error, _error} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Credenciales inválidas"})
    end
  end

  @doc "DELETE /api/user/logout - Revoca el bearer token enviado en el header."
  def logout(conn, _params) do
    conn
    |> AshAuthentication.Plug.Helpers.revoke_bearer_tokens(:aves)
    |> send_resp(:no_content, "")
  end

  defp strategy, do: Info.strategy!(User, :password)

  # Acepta `user` como alias de `email` para mantener compatibilidad con el
  # contrato inicial (birs_user_apis.yaml usaba el campo `user`).
  defp register_params(params) do
    %{
      "email" => params["email"] || params["user"],
      "nickname" => params["nickname"],
      "password" => params["password"],
      "password_confirmation" => params["password_confirmation"] || params["confirm_password"]
    }
  end

  defp sign_in_params(params) do
    %{
      "email" => params["email"] || params["user"],
      "password" => params["password"]
    }
  end

  defp auth_response(user) do
    %{
      user: %{
        id: user.id,
        email: to_string(user.email),
        nickname: user.nickname,
        rol: to_string(user.rol)
      },
      token: user.__metadata__.token
    }
  end

  defp error_messages(error) do
    case error do
      %Ash.Error.Invalid{errors: errors} -> Enum.map(errors, &Exception.message/1)
      _ -> [Exception.message(error)]
    end
  end
end
