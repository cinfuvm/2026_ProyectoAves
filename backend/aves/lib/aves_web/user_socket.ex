defmodule AvesWeb.UserSocket do
  @moduledoc """
  WebSocket entry point for the admin channels.

  The client connects to `/socket/websocket?token=<bearer token>`. The token is
  checked with the same code as `AvesWeb.AuthPlug`, so a token that works for
  the REST API works here too. Without a valid token the connection is refused.
  """
  use Phoenix.Socket

  alias AshAuthentication.Plug.Helpers

  channel "stats:*", AvesWeb.StatsChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) when is_binary(token) do
    conn = Plug.Conn.put_req_header(%Plug.Conn{}, "authorization", "Bearer " <> token)

    case Helpers.retrieve_from_bearer(conn, :aves) do
      %{assigns: %{current_user: %{} = user}} -> {:ok, assign(socket, :current_user, user)}
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
