defmodule AvesWeb.MetricsAuth do
  @moduledoc """
  Basic auth for `GET /metrics`. The credentials come from
  `config :aves, :metrics_auth`: `METRICS_USER` and `METRICS_PASSWORD` in
  production, with a development default in `config/config.exs`.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    credentials = Application.fetch_env!(:aves, :metrics_auth)

    Plug.BasicAuth.basic_auth(conn,
      username: credentials[:username],
      password: credentials[:password],
      realm: "metrics"
    )
  end
end
