defmodule LandingWeb.AuthController do
  use LandingWeb, :controller

  @request_timeout 5_000

  def login(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    if String.trim(email) == "" or String.trim(password) == "" do
      conn
      |> put_flash(:error, "Ingresa tu correo y contraseña.")
      |> redirect(to: ~p"/login/")
    else
      authenticate(conn, "/api/user/login", %{email: email, password: password}, ~p"/login/")
    end
  end

  def login(conn, _params) do
    conn
    |> put_flash(:error, "Ingresa tu correo y contraseña.")
    |> redirect(to: ~p"/login/")
  end

  def signup(
        conn,
        %{
          "username" => nickname,
          "email" => email,
          "password" => password,
          "password_confirmation" => password_confirmation
        }
      )
      when is_binary(nickname) and is_binary(email) and is_binary(password) and
             is_binary(password_confirmation) do
    cond do
      String.trim(nickname) == "" or String.trim(email) == "" or String.trim(password) == "" ->
        signup_error(conn, "Completa todos los campos.")

      password != password_confirmation ->
        signup_error(conn, "Las contraseñas no coinciden.")

      true ->
        authenticate(
          conn,
          "/api/user/signin",
          %{
            nickname: nickname,
            email: email,
            password: password,
            password_confirmation: password_confirmation
          },
          ~p"/signup/"
        )
    end
  end

  def signup(conn, _params) do
    signup_error(conn, "Completa todos los campos.")
  end

  def logout(conn, _params) do
    case revoke_token(get_session(conn, "token")) do
      :ok ->
        conn
        |> clear_session()
        |> put_flash(:info, "Has cerrado sesión.")
        |> redirect(to: ~p"/propaganda/")

      {:error, :unavailable} ->
        conn
        |> put_flash(:error, "No se pudo confirmar el cierre de sesión con el servidor.")
        |> redirect(to: ~p"/propaganda/")
    end
  end

  defp authenticate(conn, path, payload, failure_path) do
    case api_post(path, payload) do
      {:ok, %{"token" => token, "user" => user}}
      when is_binary(token) and token != "" and is_map(user) ->
        conn
        |> configure_session(renew: true)
        |> put_session("token", token)
        |> put_session("current_user", session_user(user))
        |> put_flash(:info, "Sesión iniciada correctamente.")
        |> redirect(to: ~p"/propaganda/")

      {:ok, _body} ->
        conn
        |> put_flash(:error, "El servidor devolvió una respuesta de autenticación inválida.")
        |> redirect(to: failure_path)

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: failure_path)
    end
  end

  defp api_post(path, payload) do
    url = api_url(path)
    request_options = Application.get_env(:landing, :aves_api_req_options, [])

    case Req.post(
           [
             url: url,
             json: payload,
             receive_timeout: @request_timeout,
             retry: false
           ] ++ request_options
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: 401}} ->
        {:error, "El correo o la contraseña no son correctos."}

      {:ok, %Req.Response{status: 422, body: body}} ->
        {:error, validation_message(body)}

      {:ok, %Req.Response{}} ->
        {:error, "El servidor no pudo completar la solicitud. Inténtalo nuevamente."}

      {:error, _error} ->
        {:error, "No se pudo conectar con el servidor. Inténtalo nuevamente más tarde."}
    end
  end

  defp revoke_token(token) when is_binary(token) do
    request_options = Application.get_env(:landing, :aves_api_req_options, [])

    case Req.delete(
           [
             url: api_url("/api/user/logout"),
             headers: [{"authorization", "Bearer #{token}"}],
             receive_timeout: @request_timeout,
             retry: false
           ] ++ request_options
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      _ -> {:error, :unavailable}
    end
  end

  defp revoke_token(nil), do: :ok
  defp revoke_token(_token), do: {:error, :unavailable}

  defp api_url(path) do
    base_url =
      :landing
      |> Application.fetch_env!(:aves_api_url)
      |> String.trim_trailing("/")

    base_url <> path
  end

  defp validation_message(%{"errors" => errors}) when is_list(errors) do
    message =
      errors
      |> Enum.filter(&is_binary/1)
      |> Enum.take(3)
      |> Enum.map(&String.slice(&1, 0, 200))
      |> Enum.join(" ")

    if message == "",
      do: "No se pudo crear la cuenta. Revisa tus datos e inténtalo nuevamente.",
      else: message
  end

  defp validation_message(_body),
    do: "No se pudo crear la cuenta. Revisa tus datos e inténtalo nuevamente."

  defp session_user(user) do
    Map.take(user, ["id", "email", "nickname", "rol"])
  end

  defp signup_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/signup/")
  end
end
