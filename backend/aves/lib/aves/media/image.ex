defmodule Aves.Media.Image do
  @moduledoc """
  Fotografía de avistamiento publicada en el catálogo.

  El binario se guarda en disco (`priv/static/uploads`) y en la base de datos
  solo viven los metadatos; `url` es la dirección absoluta que recibe el
  cliente para mostrar la imagen, y `ruta` la ruta relativa dentro de
  `priv/static` que sirve `Plug.Static`.
  """

  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "images"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :ruta,
        :url,
        :categoria,
        :mime,
        :tamano,
        :autor_id,
        :autor_nombre,
        :lugar,
        :fecha,
        :comentario
      ]
    end
  end

  policies do
    # El catálogo es público: cualquiera puede verlo, con o sin token.
    policy action_type(:read) do
      authorize_if always()
    end

    # Publicar exige estar autenticado (el actor lo fija `AvesWeb.AuthPlug`).
    policy action_type(:create) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :ruta, :string do
      allow_nil? false
      public? true
    end

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :categoria, :string do
      allow_nil? false
      public? true
    end

    attribute :mime, :string do
      allow_nil? false
      public? true
    end

    attribute :tamano, :integer do
      allow_nil? false
      public? true
    end

    attribute :lugar, :string do
      public? true
    end

    attribute :fecha, :string do
      public? true
    end

    attribute :comentario, :string do
      public? true
    end

    # Apodo del autor congelado al subir, para poder mostrarlo en la ficha
    # sin cargar la relación `autor`.
    attribute :autor_nombre, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :autor, Aves.Accounts.User do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end
end
