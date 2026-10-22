defmodule Aves.Factory do
  @moduledoc """
  Test factories for users and catalog resources.

  Creates users through the real AshAuthentication password strategy (so the
  bearer token is persisted and accepted by `AvesWeb.AuthPlug`), then adjusts
  the role with `Ash.Seed` when a moderator/admin actor is needed.
  """
  alias AshAuthentication.Strategy
  alias Aves.Accounts.User
  alias Aves.Catalog.{Bird, Category}
  alias Aves.Bitacora.Sighting

  @password "supersecret123"

  @doc """
  Registers a user and returns `{user, token}`.

  The token is persisted via the real sign-in flow, so it is accepted by
  `AvesWeb.AuthPlug`. Use `role` to build moderator/admin actors for RF-14.
  """
  def user_with_token(role \\ :usuario, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    register_attrs = %{
      "email" => Map.get(attrs, :email, "user#{suffix}@example.com"),
      "nickname" => Map.get(attrs, :nickname, "user#{suffix}"),
      "password" => @password,
      "password_confirmation" => @password
    }

    {:ok, user} = Strategy.action(strategy(), :register, register_attrs)
    token = user.__metadata__.token

    user =
      if role == :usuario do
        user
      else
        Ash.Seed.update!(user, %{rol: role})
      end

    {user, token}
  end

  @doc "Registers a user; returns the `%User{}` only."
  def user(role \\ :usuario, attrs \\ %{}) do
    {user, _token} = user_with_token(role, attrs)
    user
  end

  @doc "A convenience actor with `:moderador` role (for RF-14 tests)."
  def moderator(attrs \\ %{}), do: user(:moderador, attrs)

  @doc "A convenience actor with `:admin` role."
  def admin(attrs \\ %{}), do: user(:admin, attrs)

  @doc "Creates a category with a unique name."
  def category(attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    Category
    |> Ash.Seed.seed!(Map.merge(%{name: "categoria-#{suffix}"}, attrs))
  end

  @doc "Creates a bird (optionally attached to a category)."
  def bird(attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    Bird
    |> Ash.Seed.seed!(Map.merge(%{name: "ave-#{suffix}"}, attrs))
  end

  @doc """
  Creates a sighting owned by `owner` (bypassing policies, for test setup only).

  Defaults to a valid photo URL and today's date.
  """
  def sighting(owner, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    base = %{
      place: "Parque #{suffix}",
      spotted_on: Date.utc_today(),
      photo_url: "https://example.com/foto-#{suffix}.jpg",
      owner_id: owner.id
    }

    Sighting
    |> Ash.Seed.seed!(Map.merge(base, attrs))
  end

  @doc """
  Bytes of a minimal, structurally valid JPEG: SOI, a JFIF segment, any extra
  segments given, a scan header and EOI. `Aves.Storage` parses this structure,
  so test photos must have it.
  """
  def jpeg_bytes(extra_segments \\ <<>>) do
    jfif =
      <<0xFF, 0xE0, 0x00, 0x10, "JFIF", 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x00>>

    <<0xFF, 0xD8>> <> jfif <> extra_segments <> <<0xFF, 0xDA, 0x00, 0x02, "x", 0xFF, 0xD9>>
  end

  @doc "Wraps `payload` in an APP1 (EXIF) segment, as a camera would."
  def exif_segment(payload), do: segment(0xE1, payload)

  @doc "Wraps `payload` in a COM (comment) segment."
  def comment_segment(payload), do: segment(0xFE, payload)

  defp segment(marker, payload), do: <<0xFF, marker, 2 + byte_size(payload)::16>> <> payload

  @doc "Adds a bearer authorization header for the given token to the conn."
  def sign_in_conn(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc "Authenticates the conn as `user` using a fresh token."
  def sign_in(conn, user) do
    token = sign_in_token(user)
    sign_in_conn(conn, token)
  end

  @doc "Signs in a persisted user and returns a valid bearer token."
  def sign_in_token(user) do
    strategy = strategy()

    attrs = %{
      "email" => to_string(user.email),
      "password" => @password
    }

    {:ok, signed_in} = Strategy.action(strategy, :sign_in, attrs)
    signed_in.__metadata__.token
  end

  defp strategy, do: AshAuthentication.Info.strategy!(User, :password)
end
