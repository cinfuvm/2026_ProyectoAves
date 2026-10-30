defmodule AvesWeb.StatsChannel do
  @moduledoc """
  Admin statistics over WebSocket, topic `stats:admin`.

  Only users with the `admin` role can join. On join the server pushes a
  `snapshot` event with the numbers from `Aves.Stats.snapshot/0`, and pushes a
  new one every 30 seconds. The client can ask for one right away by sending
  a `refresh` event.
  """
  use AvesWeb, :channel

  alias Aves.Stats

  @refresh_ms 30_000

  @impl true
  def join("stats:admin", _params, socket) do
    case socket.assigns.current_user do
      %{rol: :admin} ->
        send(self(), :push_snapshot)
        {:ok, socket}

      _ ->
        {:error, %{reason: "forbidden"}}
    end
  end

  def join(_topic, _params, _socket), do: {:error, %{reason: "unknown topic"}}

  @impl true
  def handle_info(:push_snapshot, socket) do
    push(socket, "snapshot", Stats.snapshot())
    Process.send_after(self(), :push_snapshot, @refresh_ms)
    {:noreply, socket}
  end

  @impl true
  def handle_in("refresh", _payload, socket) do
    push(socket, "snapshot", Stats.snapshot())
    {:noreply, socket}
  end
end
