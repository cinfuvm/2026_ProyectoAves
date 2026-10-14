defmodule Aves.Accounts.UserPoliciesTest do
  use Aves.DataCase, async: true

  alias Aves.Accounts.User

  defp register do
    strategy = AshAuthentication.Info.strategy!(User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :register, %{
        "email" => "user#{System.unique_integer([:positive])}@example.com",
        "nickname" => "user#{System.unique_integer([:positive])}",
        "password" => "supersecret123",
        "password_confirmation" => "supersecret123"
      })

    user
  end

  defp create_user(:usuario), do: register()

  defp create_user(rol) do
    user = register()
    {:ok, user} = Ash.update(user, %{rol: rol}, action: :assign_role, authorize?: false)
    user
  end

  describe "update :assign_role" do
    test "un administrador puede asignar roles" do
      admin = create_user(:admin)
      target = create_user(:usuario)

      assert Ash.can?({target, :assign_role}, admin)
    end

    test "un usuario común no puede asignar roles" do
      user = create_user(:usuario)
      target = create_user(:usuario)

      refute Ash.can?({target, :assign_role}, user)
    end

    test "un moderador no puede asignar roles" do
      moderador = create_user(:moderador)
      target = create_user(:usuario)

      refute Ash.can?({target, :assign_role}, moderador)
    end
  end

  describe "read" do
    test "un usuario puede leer su propio perfil" do
      user = create_user(:usuario)

      assert Ash.can?({user, :read}, user)
    end

    test "un usuario no puede leer el perfil de otro" do
      user = create_user(:usuario)
      other = create_user(:usuario)

      refute Ash.can?({other, :read}, user)
    end

    test "un moderador puede leer el perfil de cualquier usuario" do
      moderador = create_user(:moderador)
      other = create_user(:usuario)

      assert Ash.can?({other, :read}, moderador)
    end

    test "un invitado no puede leer perfiles" do
      other = create_user(:usuario)

      refute Ash.can?({other, :read}, nil)
    end
  end

  describe "destroy" do
    test "un moderador puede eliminar a un usuario común" do
      moderador = create_user(:moderador)
      target = create_user(:usuario)

      assert Ash.can?({target, :destroy}, moderador)
    end

    test "un moderador no puede eliminar a otro moderador" do
      moderador = create_user(:moderador)
      target = create_user(:moderador)

      refute Ash.can?({target, :destroy}, moderador)
    end

    test "un moderador no puede eliminar a un administrador" do
      moderador = create_user(:moderador)
      target = create_user(:admin)

      refute Ash.can?({target, :destroy}, moderador)
    end

    test "un administrador puede eliminar a cualquier rol" do
      admin = create_user(:admin)
      moderador = create_user(:moderador)

      assert Ash.can?({moderador, :destroy}, admin)
    end

    test "un usuario común no puede eliminar a otro usuario" do
      user = create_user(:usuario)
      target = create_user(:usuario)

      refute Ash.can?({target, :destroy}, user)
    end

    test "un invitado no puede eliminar usuarios" do
      target = create_user(:usuario)

      refute Ash.can?({target, :destroy}, nil)
    end
  end

  describe "create_admin/1" do
    test "crea un usuario administrador nuevo" do
      assert {:ok, user} =
               Aves.Accounts.create_admin(%{
                 email: "root@example.com",
                 nickname: "root",
                 password: "supersecret123"
               })

      assert user.rol == :admin
    end

    test "promueve a administrador un usuario existente" do
      existing = create_user(:usuario)

      assert {:ok, promoted} =
               Aves.Accounts.create_admin(%{
                 email: to_string(existing.email),
                 password: "supersecret123"
               })

      assert promoted.id == existing.id
      assert promoted.rol == :admin
    end
  end
end
