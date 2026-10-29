defmodule Aves.Stats do
  @moduledoc """
  Business numbers for the admin: users by role, birds, sightings by state,
  reports by status, collection items, bird views, the popular birds and the
  free disk space of the photos folder.

  The numbers reach the admin through the `stats:admin` channel
  (`AvesWeb.StatsChannel`), and Prometheus through `emit_metrics/0`, which
  `Aves.PromEx.StatsPlugin` polls.

  The queries are plain SQL on purpose: they count whole tables. The Ash
  policies are not needed here because the channel checks the admin role on
  join.
  """

  @top_birds 10
  @roles ~w(usuario moderador admin)
  @report_statuses ~w(pendiente aprobado retirado)

  @doc """
  Current numbers. The keys are atoms, except `users` and `reports`, whose keys
  are the role and status names as stored.
  """
  def snapshot do
    %{
      users: users_by_rol(),
      birds: count("SELECT COUNT(*) FROM birds"),
      sightings: sightings_by_state(),
      reports: reports_by_status(),
      collection_items: count("SELECT COUNT(*) FROM collection_items"),
      bird_views: count("SELECT COUNT(*) FROM bird_views"),
      popular_birds: popular_birds(),
      uploads_free_bytes: uploads_free_bytes(),
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Publishes the snapshot as Telemetry events, so Prometheus can scrape it. Roles
  and statuses with no rows are published as 0, so their series do not vanish.
  """
  def emit_metrics do
    snap = snapshot()

    for {rol, count} <- with_defaults(snap.users, @roles) do
      :telemetry.execute([:aves, :users], %{count: count}, %{rol: rol})
    end

    for {state, count} <- snap.sightings do
      :telemetry.execute([:aves, :sightings], %{count: count}, %{state: state})
    end

    for {status, count} <- with_defaults(snap.reports, @report_statuses) do
      :telemetry.execute([:aves, :reports], %{count: count}, %{status: status})
    end

    :telemetry.execute([:aves, :birds], %{count: snap.birds}, %{})
    :telemetry.execute([:aves, :collection_items], %{count: snap.collection_items}, %{})
    :telemetry.execute([:aves, :bird_views], %{count: snap.bird_views}, %{})

    if snap.uploads_free_bytes do
      :telemetry.execute([:aves, :uploads], %{free_bytes: snap.uploads_free_bytes}, %{})
    end

    :ok
  end

  @doc """
  Free bytes on the disk that holds the photos folder, or `nil` if `df` fails.
  The folder is created first, so the disk can be measured before any upload.
  """
  def uploads_free_bytes do
    dir = Aves.Storage.uploads_dir()
    File.mkdir_p!(dir)

    case System.cmd("df", ["-Pk", dir], stderr_to_stdout: true) do
      {output, 0} ->
        [_header, data | _] = String.split(output, "\n", trim: true)
        [_filesystem, _blocks, _used, available | _] = String.split(data)
        String.to_integer(available) * 1024

      _ ->
        nil
    end
  end

  defp users_by_rol, do: query_map("SELECT rol, COUNT(*) FROM users GROUP BY rol")

  defp reports_by_status,
    do: query_map("SELECT status, COUNT(*) FROM reports GROUP BY status")

  defp sightings_by_state do
    [[visible, hidden, deleted]] =
      rows("""
      SELECT
        COUNT(*) FILTER (WHERE deleted_at IS NULL AND hidden_at IS NULL),
        COUNT(*) FILTER (WHERE deleted_at IS NULL AND hidden_at IS NOT NULL),
        COUNT(*) FILTER (WHERE deleted_at IS NOT NULL)
      FROM sightings
      """)

    %{visible: visible, hidden: hidden, deleted: deleted}
  end

  defp popular_birds do
    """
    SELECT b.id::text, b.name, COUNT(v.id) AS views
    FROM bird_views v
    JOIN birds b ON b.id = v.bird_id
    GROUP BY b.id, b.name
    ORDER BY views DESC, b.name ASC
    LIMIT $1
    """
    |> rows([@top_birds])
    |> Enum.map(fn [id, name, views] -> %{id: id, name: name, views: views} end)
  end

  defp count(sql), do: sql |> rows() |> hd() |> hd()

  defp query_map(sql), do: Map.new(rows(sql), fn [key, count] -> {key, count} end)

  defp with_defaults(counts, keys) do
    Enum.reduce(keys, counts, fn key, acc -> Map.put_new(acc, key, 0) end)
  end

  defp rows(sql, params \\ []) do
    Ecto.Adapters.SQL.query!(Aves.Repo, sql, params).rows
  end
end
