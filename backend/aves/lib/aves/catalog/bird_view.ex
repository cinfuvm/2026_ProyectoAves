defmodule Aves.Catalog.BirdView do
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "bird_views"
    repo Aves.Repo

    references do
      reference :bird, on_delete: :delete
    end

    custom_indexes do
      index [:bird_id]
    end
  end

  actions do
    defaults [:read]

    create :record do
      accept [:bird_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :bird, Aves.Catalog.Bird do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end
end
