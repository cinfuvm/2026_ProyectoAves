# =============================================================================
# TESTS DE POLÍTICAS DE USUARIO (AUTORIZACIÓN POR ROLES)
# =============================================================================
#
# Archivo: test/aves/accounts/user_policies_test.exs
#
# ¿QUÉ PRUEBA ESTE ARCHIVO?
#   Las políticas de autorización (Ash policies) del recurso
#   `Aves.Accounts.User`: quién puede leer, editar, eliminar y
#   asignar roles, según el rol del usuario que ejecuta la acción.
#
# ROLES DEL SISTEMA:
#   :admin      -> puede todo (asignar roles, eliminar a cualquiera)
#   :moderador  -> puede leer cualquier perfil y eliminar usuarios comunes
#   :usuario    -> sólo puede ver/editar su propio perfil
#   nil         -> invitado (no autenticado): no puede hacer nada
#
# ¿CÓMO SE EJECUTA? (desde la carpeta `aves/`)
#   mix test test/aves/accounts/user_policies_test.exs
#
# NOTAS:
#   * Usa `Aves.DataCase` (async: true). Corre tests en paralelo sobre el
#     sandbox de la base de datos, sin mezclar datos entre ellos.
#   * `Ash.can?({recurso, accion}, actor)` pregunta si `actor` puede ejecutar
#     `accion` sobre `recurso`. Devuelve true/false.
#   * Los tests usan `authorize?: false` al preparar datos, para "saltarse"
#     las políticas mientras se crean los usuarios de prueba.
# =============================================================================
defmodule Aves.Accounts.UserPoliciesTest do
  use Aves.DataCase, async: true

  alias Aves.Accounts.User

  # Registra un usuario nuevo (rol por defecto :usuario) usando el flujo real
  # de AshAuthentication (estrategia :password). El email y nickname son
  # únicos para evitar colisiones entre tests.
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

  # Crea un usuario con rol ":usuario" (el registro normal ya lo hace).
  defp create_user(:usuario), do: register()

  # Crea un usuario y luego le asigna un rol concreto (ej. :admin o :moderador).
  # Se usa `authorize?: false` porque aquí sólo preparamos datos, no autorizamos.
  defp create_user(rol) do
    user = register()
    {:ok, user} = Ash.update(user, %{rol: rol}, action: :assign_role, authorize?: false)
    user
  end

  # ---------------------------------------------------------------------------
  # Acción: update :assign_role  -> asignar roles a otros usuarios
  # ---------------------------------------------------------------------------
  describe "update :assign_role" do
    # Sólo un administrador puede repartir roles.
    test "un administrador puede asignar roles" do
      admin = create_user(:admin)
      target = create_user(:usuario)

      assert Ash.can?({target, :assign_role}, admin)
    end

    # Un usuario normal no puede cambiar roles (ni el suyo ni el de otros).
    test "un usuario común no puede asignar roles" do
      user = create_user(:usuario)
      target = create_user(:usuario)

      refute Ash.can?({target, :assign_role}, user)
    end

    # El moderador, aunque tiene privilegios sobre perfiles, NO asigna roles.
    test "un moderador no puede asignar roles" do
      moderador = create_user(:moderador)
      target = create_user(:usuario)

      refute Ash.can?({target, :assign_role}, moderador)
    end
  end

  # ---------------------------------------------------------------------------
  # Acción: read  -> leer perfiles
  # ---------------------------------------------------------------------------
  describe "read" do
    # Cada quien puede ver su propio perfil.
    test "un usuario puede leer su propio perfil" do
      user = create_user(:usuario)

      assert Ash.can?({user, :read}, user)
    end

    # Pero no el de otros usuarios.
    test "un usuario no puede leer el perfil de otro" do
      user = create_user(:usuario)
      other = create_user(:usuario)

      refute Ash.can?({other, :read}, user)
    end

    # El moderador sí puede leer cualquier perfil (labor de moderación).
    test "un moderador puede leer el perfil de cualquier usuario" do
      moderador = create_user(:moderador)
      other = create_user(:usuario)

      assert Ash.can?({other, :read}, moderador)
    end

    # Un invitado (actor = nil) no tiene acceso.
    test "un invitado no puede leer perfiles" do
      other = create_user(:usuario)

      refute Ash.can?({other, :read}, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Acción: destroy  -> eliminar usuarios
  # ---------------------------------------------------------------------------
  describe "destroy" do
    # El moderador puede eliminar usuarios comunes.
    test "un moderador puede eliminar a un usuario común" do
      moderador = create_user(:moderador)
      target = create_user(:usuario)

      assert Ash.can?({target, :destroy}, moderador)
    end

    # Pero no a otro moderador (mismo nivel).
    test "un moderador no puede eliminar a otro moderador" do
      moderador = create_user(:moderador)
      target = create_user(:moderador)

      refute Ash.can?({target, :destroy}, moderador)
    end

    # Tampoco a un administrador (nivel superior).
    test "un moderador no puede eliminar a un administrador" do
      moderador = create_user(:moderador)
      target = create_user(:admin)

      refute Ash.can?({target, :destroy}, moderador)
    end

    # El administrador puede eliminar a cualquier rol.
    test "un administrador puede eliminar a cualquier rol" do
      admin = create_user(:admin)
      moderador = create_user(:moderador)

      assert Ash.can?({moderador, :destroy}, admin)
    end

    # Un usuario común no tiene permiso de borrado.
    test "un usuario común no puede eliminar a otro usuario" do
      user = create_user(:usuario)
      target = create_user(:usuario)

      refute Ash.can?({target, :destroy}, user)
    end

    # Ni un invitado.
    test "un invitado no puede eliminar usuarios" do
      target = create_user(:usuario)

      refute Ash.can?({target, :destroy}, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Acción: update :update_profile  -> editar perfiles
  # ---------------------------------------------------------------------------
  describe "update :update_profile" do
    # Puedo editar mi propio perfil.
    test "un usuario puede editar su propio perfil" do
      user = create_user(:usuario)

      assert Ash.can?({user, :update_profile}, user)
    end

    # No puedo editar el perfil de otra persona.
    test "un usuario no puede editar el perfil de otro" do
      user = create_user(:usuario)
      other = create_user(:usuario)

      refute Ash.can?({other, :update_profile}, user)
    end

    # Un invitado no edita nada.
    test "un invitado no puede editar perfiles" do
      user = create_user(:usuario)

      refute Ash.can?({user, :update_profile}, nil)
    end

    # Defensa en profundidad: editar el perfil NO otorga permiso para
    # cambiar el rol (esa es otra acción con su propia política).
    test "un usuario no puede auto-asignarse un rol vía assign_role" do
      user = create_user(:usuario)

      refute Ash.can?({user, :assign_role}, user)
    end
  end

  # ---------------------------------------------------------------------------
  # Función de conveniencia: Aves.Accounts.create_admin/1
  # ---------------------------------------------------------------------------
  describe "create_admin/1" do
    # Si el usuario no existe, lo crea directamente como :admin.
    test "crea un usuario administrador nuevo" do
      assert {:ok, user} =
               Aves.Accounts.create_admin(%{
                 email: "root@example.com",
                 nickname: "root",
                 password: "supersecret123"
               })

      assert user.rol == :admin
    end

    # Si el usuario ya existe, lo promueve a :admin (no lo duplica).
    test "promueve a administrador un usuario existente" do
      existing = create_user(:usuario)

      assert {:ok, promoted} =
               Aves.Accounts.create_admin(%{
                 email: to_string(existing.email),
                 password: "supersecret123"
               })

      # Es el MISMO usuario (mismo id), sólo cambió de rol.
      assert promoted.id == existing.id
      assert promoted.rol == :admin
    end
  end
end
