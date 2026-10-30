defmodule Aves.Moderation.Report do
  @moduledoc """
  A report claiming a sighting photo does not correspond to a bird (RF-13).

  Reports feed the moderator queue (RF-14): a moderator can approve (photo
  stays visible) or retire (photo gets hidden) the reported sighting.
  """
  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Moderation,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "reports"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :report do
      description "Report a sighting photo that does not correspond to a bird (RF-13)."
      accept [:sighting_id, :reason]
      change relate_actor(:reporter)
    end

    update :approve do
      description "Approve the report; the photo stays visible (RF-14)."
      require_atomic? false
      accept []
      change set_attribute(:status, :aprobado)
    end

    update :retire do
      description "Retire the report; the reported photo is hidden (RF-14)."
      require_atomic? false
      accept []
      change set_attribute(:status, :retirado)
    end
  end

  policies do
    # Any authenticated user can file a report (RF-13).
    policy action(:report) do
      authorize_if actor_present()
    end

    # Moderator queue: only moderators/admins (RF-14). For read actions this
    # acts as a filter, so non-moderators get an empty queue; for approve/retire
    # it denies the fetch, surfacing as 404. Either way no moderator data leaks.
    policy action([:read, :approve, :retire]) do
      authorize_if expr(^actor(:rol) in [:moderador, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reason, :string do
      description "Free-text reason for the report."
      allow_nil? true
      public? true
    end

    attribute :status, :atom do
      description "Moderation status of the report."
      constraints one_of: [:pendiente, :aprobado, :retirado]
      default :pendiente
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :reporter, Aves.Accounts.User do
      allow_nil? false
      attribute_writable? true
      public? true
    end

    belongs_to :sighting, Aves.Bitacora.Sighting do
      allow_nil? false
      public? true
    end
  end
end
