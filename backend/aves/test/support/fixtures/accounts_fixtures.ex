defmodule Aves.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Aves.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "some email",
        nickname: "some nickname",
        password_hash: "some password_hash",
        rol: "some rol"
      })
      |> Aves.Accounts.create_user()

    user
  end
end
