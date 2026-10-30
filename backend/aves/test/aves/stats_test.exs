defmodule Aves.StatsTest do
  @moduledoc """
  Counts of `Aves.Stats.snapshot/0`. Each test builds its own data, and the SQL
  sandbox isolates the tests from one another.
  """
  use Aves.DataCase

  import Aves.Factory

  alias Aves.Bitacora.CollectionItem
  alias Aves.Catalog.BirdView
  alias Aves.Moderation.Report
  alias Aves.Stats

  test "cuenta usuarios por rol" do
    user_with_token()
    user_with_token()
    user_with_token(:moderador)
    user_with_token(:admin)

    snap = Stats.snapshot()

    assert snap.users == %{"usuario" => 2, "moderador" => 1, "admin" => 1}
  end

  test "cuenta avistamientos por estado: visibles, ocultos y eliminados" do
    {owner, _} = user_with_token()
    now = DateTime.utc_now()

    sighting(owner)
    sighting(owner)
    sighting(owner, %{hidden_at: now})
    sighting(owner, %{deleted_at: now})

    assert Stats.snapshot().sightings == %{visible: 2, hidden: 1, deleted: 1}
  end

  test "cuenta reportes por estado y colección y vistas" do
    {owner, _} = user_with_token()
    {reporter, _} = user_with_token()
    bird = bird(%{})
    photo = sighting(owner, %{bird_id: bird.id})

    Ash.Seed.seed!(Report, %{
      reporter_id: reporter.id,
      sighting_id: photo.id,
      reason: "No es un ave",
      status: :retirado
    })

    Ash.Seed.seed!(CollectionItem, %{owner_id: reporter.id, sighting_id: photo.id})
    Ash.Seed.seed!(BirdView, %{bird_id: bird.id})
    Ash.Seed.seed!(BirdView, %{bird_id: bird.id})

    snap = Stats.snapshot()

    assert snap.reports == %{"retirado" => 1}
    assert snap.collection_items == 1
    assert snap.bird_views == 2
    assert snap.birds == 1
  end

  test "las aves populares van por vistas, de mayor a menor" do
    popular = bird(%{name: "Cisne"})
    other = bird(%{name: "Tiuque"})

    for _ <- 1..3, do: Ash.Seed.seed!(BirdView, %{bird_id: popular.id})
    Ash.Seed.seed!(BirdView, %{bird_id: other.id})

    assert [first, second] = Stats.snapshot().popular_birds
    assert first == %{id: popular.id, name: "Cisne", views: 3}
    assert second == %{id: other.id, name: "Tiuque", views: 1}
  end

  test "reporta el espacio libre del disco de fotos" do
    assert is_integer(Stats.snapshot().uploads_free_bytes)
    assert Stats.snapshot().uploads_free_bytes > 0
  end

  test "emit_metrics publica los conteos sin errores" do
    user_with_token(:admin)
    assert Stats.emit_metrics() == :ok
  end
end
