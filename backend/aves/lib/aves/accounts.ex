defmodule Aves.Accounts do
  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Accounts.Token
    resource Aves.Accounts.User
  end
end
