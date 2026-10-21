defmodule Aves.Bitacora.CollectionItem do
  @moduledoc """
  A sighting another user saved into their own personal collection (RF-12).
  """
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Bitacora,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "collection_items"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :add do
      description "Add a sighting to the actor's personal collection (RF-12)."
      accept [:sighting_id]
      change relate_actor(:owner)
    end

    destroy :remove do
      description "Remove an item from the actor's personal collection (RF-12)."
      primary? true
    end
  end

  policies do
    # List only the actor's own collection items.
    policy action(:read) do
      authorize_if expr(owner_id == ^actor(:id))
    end

    # Add/remove only within the actor's own collection.
    policy action([:add, :remove]) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Aves.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    belongs_to :sighting, Aves.Bitacora.Sighting do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_owner_sighting, [:owner_id, :sighting_id]
  end
end
