defmodule Aves.Accounts.User do
  @moduledoc """
  Usuario de la aplicación, con autenticación por usuario y contraseña.

  El identificador público es `username` y se envía en el JSON como `user`,
  que es el nombre que usa el contrato (`birds_apis.yaml`). Se llama `username`
  y no `user` dentro de la base de datos porque `user` es palabra reservada de
  Postgres y obligaría a comillas en cada consulta cruda.
  """

  use Ash.Resource,
    otp_app: :aves,
    domain: Aves.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    strategies do
      password :password do
        identity_field :username
        hashed_password_field :hashed_password
        register_action_accept [:username]
      end
    end

    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Aves.Accounts.Token
      signing_secret Aves.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end
  end

  postgres do
    table "users"
    repo Aves.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :username, :ci_string do
      allow_nil? false
      public? true
      constraints min_length: 3, max_length: 30
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :rol, :atom do
      constraints one_of: [:usuario, :moderador, :admin]
      default :usuario
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_username, [:username]
  end
end
