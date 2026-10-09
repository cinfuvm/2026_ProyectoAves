defmodule AvesWeb.AuthPlug do
  @moduledoc """
  Plug que autentica peticiones de la API a partir del header
  `Authorization: Bearer <token>`.

  Verifica el token, carga al usuario y lo establece como **actor** de Ash para
  que apliquen las policies sobre el usuario autenticado.

  Si `:require` es `true` (por defecto) y no hay un token válido, responde `401`.
  """
  @behaviour Plug

  import Plug.Conn

  alias AshAuthentication.Plug.Helpers

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    conn = Helpers.retrieve_from_bearer(conn, :aves)
    actor = conn.assigns[:current_user]

    conn =
      if actor do
        Ash.PlugHelpers.set_actor(conn, actor)
      else
        conn
      end

    if Keyword.get(opts, :require, true) && is_nil(actor) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{error: "No autenticado"}))
      |> halt()
    else
      conn
    end
  end
end
