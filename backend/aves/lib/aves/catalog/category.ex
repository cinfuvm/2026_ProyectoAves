defmodule Aves.Catalog.Category do
  @moduledoc """
  A bird category (e.g. "Rapaces", "Playeros"). Used to filter photos (RF-11).
  """
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "categories"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end

    destroy :destroy
  end

  policies do
    # Categories are public catalog data: any authenticated actor can read them.
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :birds, Aves.Catalog.Bird do
      public? true
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
