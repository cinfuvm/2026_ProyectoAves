defmodule Aves.PromEx.StatsPlugin do
  @moduledoc """
  Business gauges for Prometheus. Every `poll_rate` (30 seconds by default),
  PromEx calls `Aves.Stats.emit_metrics/0`, which publishes the numbers as
  Telemetry events. The gauges below read those events.
  """
  use PromEx.Plugin

  @impl true
  def polling_metrics(opts) do
    poll_rate =
      Keyword.get(opts, :poll_rate, Application.get_env(:aves, :stats_poll_rate, 30_000))

    Polling.build(
      :aves_stats_polling_metrics,
      poll_rate,
      {Aves.Stats, :emit_metrics, []},
      [
        last_value([:aves, :users, :count],
          event_name: [:aves, :users],
          measurement: :count,
          tags: [:rol],
          description: "Users by role."
        ),
        last_value([:aves, :birds, :count],
          event_name: [:aves, :birds],
          measurement: :count,
          description: "Birds in the catalog."
        ),
        last_value([:aves, :sightings, :count],
          event_name: [:aves, :sightings],
          measurement: :count,
          tags: [:state],
          description: "Sightings by state: visible, hidden or deleted."
        ),
        last_value([:aves, :reports, :count],
          event_name: [:aves, :reports],
          measurement: :count,
          tags: [:status],
          description: "Photo reports by status."
        ),
        last_value([:aves, :collection_items, :count],
          event_name: [:aves, :collection_items],
          measurement: :count,
          description: "Photos saved into personal collections."
        ),
        last_value([:aves, :bird_views, :count],
          event_name: [:aves, :bird_views],
          measurement: :count,
          description: "Bird detail views, the basis of the popular ranking."
        ),
        last_value([:aves, :uploads, :free, :bytes],
          event_name: [:aves, :uploads],
          measurement: :free_bytes,
          description: "Free bytes on the disk that holds the uploaded photos."
        )
      ]
    )
  end
end
