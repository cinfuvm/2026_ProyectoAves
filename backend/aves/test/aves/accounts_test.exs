defmodule Aves.AccountsTest do
  use Aves.DataCase

  alias Aves.Accounts

  describe "usuario" do
    alias Aves.Accounts.User

    import Aves.AccountsFixtures

    @invalid_attrs %{nickname: nil, email: nil, password_hash: nil, rol: nil}

    test "list_usuario/0 returns all usuario" do
      user = user_fixture()
      assert Accounts.list_usuario() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{nickname: "some nickname", email: "some email", password_hash: "some password_hash", rol: "some rol"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.nickname == "some nickname"
      assert user.email == "some email"
      assert user.password_hash == "some password_hash"
      assert user.rol == "some rol"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{nickname: "some updated nickname", email: "some updated email", password_hash: "some updated password_hash", rol: "some updated rol"}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.nickname == "some updated nickname"
      assert user.email == "some updated email"
      assert user.password_hash == "some updated password_hash"
      assert user.rol == "some updated rol"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
