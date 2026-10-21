defmodule Aves.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Aves.Accounts.User, _opts, _context) do
    Application.fetch_env(:aves, :token_signing_secret)
  end
end
