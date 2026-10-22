defmodule Aves.Repo.Migrations.AddBirdViews do
  @moduledoc """
  Creates the `bird_views` table backing `Aves.Catalog.BirdView`,
  the view counter used by the ranking feature (RF-05 / RF-06).
  """

  use Ecto.Migration

  def up do
    create table(:bird_views, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :bird_id, :uuid, null: false
    end

    alter table(:bird_views) do
      modify :bird_id,
             references(:birds,
               column: :id,
               name: "bird_views_bird_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    create index(:bird_views, [:bird_id], name: "bird_views_bird_id_index")
  end

  def down do
    drop_if_exists index(:bird_views, [:bird_id], name: "bird_views_bird_id_index")

    drop constraint(:bird_views, "bird_views_bird_id_fkey")

    alter table(:bird_views) do
      modify :bird_id, :uuid
    end

    drop table(:bird_views)
  end
end
