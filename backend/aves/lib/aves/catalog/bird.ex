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
      accept [:name, :category_id, :scientific_name, :description]
    end

    update :update do
      accept [:name, :category_id, :scientific_name, :description]
    end

    destroy :destroy
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_present()
    end

    # Only moderators and admins can manage the catalog.
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:rol) in [:moderador, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :scientific_name, :string do
      description "Scientific name from the \"Aves de Chile\" base data (RF-07)."
      public? true
    end

    attribute :description, :string do
      description "Species description shown on the bird detail page (RF-07)."
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

    has_many :photos, Aves.Bitacora.Sighting do
      description "Visible sightings of this bird, shown on the detail page (RF-07)."
      public? true
      filter expr(is_nil(hidden_at) and is_nil(deleted_at))
    end
  end

  identities do
    identity :unique_scientific_name, [:scientific_name]
  end
end
