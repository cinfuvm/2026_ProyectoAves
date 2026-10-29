defmodule AvesWeb.MetricsController do
  @moduledoc """
  `GET /metrics`: the Prometheus text format of `Aves.PromEx`. The route is
  behind basic auth (`AvesWeb.MetricsAuth`), so Prometheus must send the
  credentials from `config :aves, :metrics_auth`.
  """
  use AvesWeb, :controller

  def index(conn, _params) do
    text(conn, PromEx.get_metrics(Aves.PromEx))
  end
end
