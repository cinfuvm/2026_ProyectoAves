defmodule Aves.Repo do
  use Ecto.Repo,
    otp_app: :aves,
    adapter: Ecto.Adapters.Postgres
end
