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

# `emulador` es con el que se prueban los reportes de moderación, reservados
# al rol `admin` (`GET /images/reports`), así que se le asciende aquí. `demo`
# se queda como usuario normal para poder ver la app sin permisos.
#
# Es SQL crudo en vez de una acción de update porque el registro no acepta
# `rol` y no hace falta abrir una acción nueva en `User` solo para los seeds.
Aves.Repo.query!("UPDATE users SET rol = 'admin' WHERE username = 'emulador'")
IO.puts("Rol de emulador: admin (moderación de reportes)")
