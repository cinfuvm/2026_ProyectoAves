defmodule Aves.Media.Report do
  @moduledoc """
  Reporte de moderación abierto contra una fotografía del catálogo.

  La app envía un reporte por cada motivo marcado en el diálogo, así que una
  misma foto puede acumular varios. `estado` arranca en `:abierto` y lo
  mueve el rol `admin` desde `PUT /images/reports/:id`.

  Quién los abre es cualquier usuario autenticado; leerlos o cambiar su
  estado es labor de moderación, así que ambos quedan reservados a `admin`.
  """

  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "image_reports"
    repo Aves.Repo
  end

  @motivos [:no_es_ave, :contenido_ofensivo, :imagen_enganosa, :derechos_autor, :otro]
  @estados [:abierto, :revisado, :descartado]

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [:avistamiento_id, :motivo, :detalle, :reportado_por_id]
    end

    update :update_estado do
      primary? true
      description "Mueve un reporte de abierto a revisado o descartado."
      accept [:estado]
      # `estado` es un `:atom` con `one_of`, y Ash deja de aceptarlo de forma
      # atómica al llevar constraints; sin esto el update fallaría al validar.
      require_atomic? false
    end
  end

  policies do
    # Abrir un reporte exige estar autenticado.
    policy action_type(:create) do
      authorize_if actor_present()
    end

    # Leerlos o mover su estado solo lo hace `admin`. El texto del reporte y
    # el nombre de quien lo abrió no son públicos.
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:rol, :admin)
    end

    policy action(:update_estado) do
      authorize_if actor_attribute_equals(:rol, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :motivo, :atom do
      constraints one_of: @motivos
      allow_nil? false
      public? true
    end

    attribute :detalle, :string do
      public? true
    end

    attribute :estado, :atom do
      constraints one_of: @estados
      default :abierto
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :avistamiento, Aves.Media.Image do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :reportado_por, Aves.Accounts.User do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end
end
