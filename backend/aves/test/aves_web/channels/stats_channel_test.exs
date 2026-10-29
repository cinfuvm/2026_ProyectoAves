defmodule AvesWeb.StatsChannelTest do
  @moduledoc """
  The admin statistics over WebSocket: only admins can connect and join
  `stats:admin`, and they receive snapshots.
  """
  use AvesWeb.ConnCase

  import Phoenix.ChannelTest
  import Aves.Factory

  test "un admin se conecta, se une y recibe un snapshot" do
    {_admin, token} = user_with_token(:admin)

    assert {:ok, socket} = Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{"token" => token})

    assert {:ok, _reply, _socket} =
             subscribe_and_join(socket, AvesWeb.StatsChannel, "stats:admin")

    assert_push "snapshot", %{users: _, birds: _, sightings: _, uploads_free_bytes: _}
  end

  test "un moderador no puede unirse al canal de estadísticas" do
    {_moderador, token} = user_with_token(:moderador)

    assert {:ok, socket} = Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{"token" => token})

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(socket, AvesWeb.StatsChannel, "stats:admin")
  end

  test "un usuario común no puede unirse al canal de estadísticas" do
    {_usuario, token} = user_with_token()

    assert {:ok, socket} = Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{"token" => token})

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(socket, AvesWeb.StatsChannel, "stats:admin")
  end

  test "un token inválido no abre la conexión" do
    assert :error =
             Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{"token" => "no-es-un-token"})

    assert :error = Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{})
  end

  test "refresh devuelve un snapshot nuevo" do
    {_admin, token} = user_with_token(:admin)
    {:ok, socket} = Phoenix.ChannelTest.connect(AvesWeb.UserSocket, %{"token" => token})
    {:ok, _reply, socket} = subscribe_and_join(socket, AvesWeb.StatsChannel, "stats:admin")

    # The snapshot pushed on join.
    assert_push "snapshot", _

    Phoenix.ChannelTest.push(socket, "refresh", %{})
    assert_push "snapshot", %{users: %{"admin" => 1}}
  end
end
