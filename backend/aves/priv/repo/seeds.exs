# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Crea los usuarios de prueba del entorno local. La app móvil y la prueba de
# integración (`mobile/integration_test/bff_e2e_test.dart`) entran con estas
# credenciales, así que no las cambies sin actualizarlas también.
#
# Es idempotente: si el usuario ya existe, lo deja como está.

alias Aves.Accounts.User

contrasena = "secret123"

usuarios = ["emulador", "demo"]

for usuario <- usuarios do
  cambios =
    Ash.Changeset.for_create(
      User,
      :register_with_password,
      %{
        username: usuario,
        password: contrasena,
        password_confirmation: contrasena
      }
    )

  # Los seeds corren sin actor, así que se omite la autorización: es una
  # operación de sistema, no una petición de usuario.
  case Ash.create(cambios, authorize?: false) do
    {:ok, creado} ->
      IO.puts("Usuario creado: #{creado.username}")

    {:error, %Ash.Error.Invalid{errors: errores}} ->
      IO.puts(
        "Usuario #{usuario} ya existía: " <>
          Enum.join(Enum.map(errores, &Exception.message/1), ", ")
      )

    {:error, error} ->
      IO.puts("Usuario #{usuario} no creado: #{Exception.message(error)}")
  end
end
