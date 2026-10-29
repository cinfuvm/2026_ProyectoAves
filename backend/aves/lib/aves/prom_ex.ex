defmodule Aves.PromEx do
  @moduledoc """
  Prometheus metrics for the backend, served at `GET /metrics` (see
  `AvesWeb.MetricsController`). The HTTP server of PromEx is disabled: the
  endpoint lives in the app so it can be protected with basic auth.

  Golden signals, as the plugins expose them:

    * Latency: `*_http_request_duration_*`, by route.
    * Traffic: `*_http_requests_total`, by route and method.
    * Errors: the same counter, by status code.
    * Saturation: `*_beam_stats_run_queue_count` and `*_beam_memory_*` (VM),
      `*_ecto_repo_query_queue_time_*` (database pool) and
      `aves_uploads_free_bytes` (disk that holds the photos).

  Business numbers are published by `Aves.PromEx.StatsPlugin`.
  """
  use PromEx, otp_app: :aves

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: AvesWeb.Router, endpoint: AvesWeb.Endpoint},
      {Plugins.Ecto, repos: [Aves.Repo]},
      Aves.PromEx.StatsPlugin
    ]
  end
end
