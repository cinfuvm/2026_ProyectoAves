defmodule Aves.Catalog.Bird do
  @moduledoc """
  A bird species. Minimal resource for the sightings/moderation requirements;
  the full catalog CRUD (RF-05) and search (RF-06) live in their own issues.
  """
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "birds"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :category_id]
    end
  end

  policies do
    # Birds are public catalog data: any authenticated actor can read them.
    policy action_type(:read) do
      authorize_if actor_present()
    end

    # Only moderators and admins can manage the catalog.
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(actor.rol in [:moderador, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :category, Aves.Catalog.Category do
      allow_nil? true
      public? true
      attribute_writable? true
    end
  end
end
