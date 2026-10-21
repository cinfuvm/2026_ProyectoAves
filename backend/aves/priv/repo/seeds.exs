# Development seed data for manual API testing.
#
# Run with:
#
#     mix run priv/repo/seeds.exs
#
# It is idempotent: running it again updates nothing it already created.
# All demo users share the password below.
#
#   usuario@aves.test    / supersecret123   (rol: usuario)
#   moderador@aves.test  / supersecret123   (rol: moderador)
#   admin@aves.test      / supersecret123   (rol: admin)
#
# After seeding, sign in with POST /api/user/login to obtain a bearer token.

alias AshAuthentication.Strategy
alias Aves.Accounts.User
alias Aves.Catalog.{Bird, Category}
alias Aves.Bitacora.Sighting

defmodule Seed do
  @moduledoc false

  @password "supersecret123"

  def password, do: @password

  def ensure_user(email, nickname, role) do
    case Ash.get(User, email, authorize?: false) do
      {:ok, user} ->
        user

      {:error, _} ->
        strategy = AshAuthentication.Info.strategy!(User, :password)

        {:ok, user} =
          Strategy.action(strategy, :register, %{
            "email" => email,
            "nickname" => nickname,
            "password" => @password,
            "password_confirmation" => @password
          })

        user = if role == :usuario, do: user, else: Ash.Seed.update!(user, %{rol: role})
        IO.puts("  + user #{email} (#{role})")
        user
    end
  end

  def ensure_category(name) do
    case Ash.read(Category, authorize?: false) do
      {:ok, cats} ->
        Enum.find(cats, &(to_string(&1.name) == name)) || Ash.Seed.seed!(Category, %{name: name})
      _ ->
        Ash.Seed.seed!(Category, %{name: name})
    end
  end

  def ensure_bird(name, category_id) do
    case Ash.read(Bird, authorize?: false) do
      {:ok, birds} ->
        Enum.find(birds, &(to_string(&1.name) == name)) ||
          Ash.Seed.seed!(Bird, %{name: name, category_id: category_id})
      _ ->
        Ash.Seed.seed!(Bird, %{name: name, category_id: category_id})
    end
  end
end

IO.puts("Seeding development data...")

user = Seed.ensure_user("usuario@aves.test", "ana", :usuario)
_other = Seed.ensure_user("otro@aves.test", "beto", :usuario)
_moderator = Seed.ensure_user("moderador@aves.test", "mod_marta", :moderador)
_admin = Seed.ensure_user("admin@aves.test", "admin_alex", :admin)

aves = Seed.ensure_category("Aves")
rapaces = Seed.ensure_category("Rapaces")

bird1 = Seed.ensure_bird("Flamenco chileno", aves.id)
bird2 = Seed.ensure_bird("Cóndor andino", rapaces.id)
bird3 = Seed.ensure_bird("Picaflor", aves.id)

# A few sightings owned by the regular user (RF-08/RF-10 baseline).
case Ash.read(Sighting, authorize?: false) do
  {:ok, []} ->
    for {place, photo, bird} <- [
          {"Reserva Costanera", "https://example.com/flamenco.jpg", bird1},
          {"Cajón del Maipo", "https://example.com/condor.png", bird2},
          {"Parque Bicentenario", "https://example.com/picaflor.jpeg", bird3}
        ] do
      Ash.Seed.seed!(Sighting, %{
        place: place,
        spotted_on: Date.utc_today(),
        photo_url: photo,
        bird_id: bird.id,
        owner_id: user.id
      })
    end

    IO.puts("  + 3 sightings for usuario@aves.test")

  _ ->
    IO.puts("  = sightings already present, skipping")
end
IO.puts("\nDone. All demo users share the password: #{Seed.password()}")
IO.puts("Sign in via POST /api/user/login with {email, password}.\n")

