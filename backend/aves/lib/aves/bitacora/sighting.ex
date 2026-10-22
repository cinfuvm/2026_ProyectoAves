defmodule Aves.Bitacora.Sighting do
  @moduledoc """
  A user's bird sighting: place, date, comment and a single photograph.

  Backs RF-08 (register), RF-09 (edit/delete own) and RF-10 (personal log).
  Sightings are the "photos" surfaced by RF-11 (other users' photos) and can be
  added to a personal collection (RF-12) or reported (RF-13/RF-14).
  """
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Bitacora,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "sightings"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :register do
      description "Register a sighting (RF-08)."
      primary? true
      accept [:place, :spotted_on, :comment, :photo_url, :bird_id]
      change relate_actor(:owner)
    end

    update :update do
      description "Edit an own sighting (RF-09)."
      accept [:place, :spotted_on, :comment, :photo_url, :bird_id]
    end

    update :soft_delete do
      description "Logically delete an own sighting (RF-09)."
      require_atomic? false
      accept []
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    update :hide do
      description "Moderator hides a reported sighting (RF-14)."
      require_atomic? false
      accept []
      change set_attribute(:hidden_at, &DateTime.utc_now/0)
    end

    read :personal_log do
      description "Personal log of the actor's sightings (RF-10)."
      pagination offset?: true, keyset?: false, required?: false
      prepare build(sort: [spotted_on: :desc, inserted_at: :desc])
    end

    read :public do
      description "Visible sightings from other users (RF-11)."
      pagination offset?: true, keyset?: false, required?: false
      prepare build(sort: [spotted_on: :desc, inserted_at: :desc])
    end
  end

  policies do
    # Register: any authenticated user.
    policy action(:register) do
      authorize_if actor_present()
    end

    # Personal log: only the owner's own, non-deleted sightings (RF-10).
    policy action(:personal_log) do
      authorize_if expr(owner_id == ^actor(:id) and is_nil(deleted_at))
    end

    # Public feed: any authenticated user sees visible (non-hidden,
    # non-deleted) sightings from OTHER users (RF-11).
    policy action(:public) do
      authorize_if expr(is_nil(hidden_at) and is_nil(deleted_at) and owner_id != ^actor(:id))
    end

    # Edit/delete: only the owner, and only while not logically deleted (RF-09).
    policy action([:update, :soft_delete]) do
      authorize_if expr(owner_id == ^actor(:id) and is_nil(deleted_at))
    end

    # Hide: only moderators/admins, as part of RF-14.
    policy action(:hide) do
      authorize_if expr(^actor(:rol) in [:moderador, :admin])
    end

    # Generic :read: used to load related sightings (e.g. collection items).
    # Allows reading visible (public) sightings and any own sighting, plus
    # any sighting for moderators/admins. Does NOT expose other users' private
    # logs, which are only reachable via :personal_log.
    policy action(:read) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if expr(is_nil(hidden_at) and is_nil(deleted_at))
      authorize_if expr(^actor(:rol) in [:moderador, :admin])
    end
  end

  validations do
    validate match(:photo_url, ~r/\.(jpe?g|png)(\?.*)?$/i),
      message: "must be a .jpg, .jpeg or .png image URL",
      where: [changing(:photo_url)]
  end

  attributes do
    uuid_primary_key :id

    attribute :place, :string do
      description "Free-text place where the bird was spotted."
      allow_nil? false
      public? true
    end

    attribute :spotted_on, :date do
      description "Date the bird was spotted."
      allow_nil? false
      public? true
    end

    attribute :comment, :string do
      allow_nil? true
      public? true
    end

    attribute :photo_url, :string do
      description "URL of the sighting photograph (required)."
      allow_nil? false
      public? true
    end

    attribute :hidden_at, :utc_datetime_usec do
      description "Set when a moderator retires the photo (RF-14)."
      allow_nil? true
      public? true
    end

    attribute :deleted_at, :utc_datetime_usec do
      description "Logical deletion timestamp (RF-09)."
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Aves.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    belongs_to :bird, Aves.Catalog.Bird do
      allow_nil? true
      public? true
    end

    has_many :collection_items, Aves.Bitacora.CollectionItem do
      public? true
    end
  end
end
