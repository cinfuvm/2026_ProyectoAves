# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Aves.Repo.insert!(%Aves.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# priv/repo/seeds.exs
alias Aves.Repo
alias Aves.Catalog.Bird

IO.puts("Iniciando la inyección de aves por defecto al catálogo...")

# Lista oficial de aves nativas para el Instagram
aves_predeterminadas = [
  %{nombre_comun: "Siete Colores", nombre_cientifico: "Tachuris rubrigastra"},
  %{nombre_comun: "Chucao", nombre_cientifico: "rubecula"},
  %{nombre_comun: "Martín Pescador", nombre_cientifico: "Megaceryle torquata"},
  %{nombre_comun: "Loica", nombre_cientifico: "Leistes loyca"},
  %{nombre_comun: "Zorzal", nombre_cientifico: "Turdus falcklandii"},
  %{nombre_comun: "Picaflor Chico", nombre_cientifico: "Sephanoides sephaniodes"},
  %{nombre_comun: "Cometocino Patagónico", nombre_cientifico: "Phrygilus patagonicus"},
  %{nombre_comun: "Cachudito", nombre_cientifico: "Anairetes parulus"},
  %{nombre_comun: "Yeco", nombre_cientifico: "Phalacrocorax brasilianus"},
  %{nombre_comun: "Bandurria", nombre_cientifico: "Theristicus melanopis"}
]

# El script recorre la lista e inserta cada una de forma segura
Enum.each(aves_predeterminadas, fn datos_ave ->
  case Repo.get_by(Bird, nombre_cientifico: datos_ave.nombre_cientifico) do
    nil ->
      %Bird{}
      |> Bird.changeset(datos_ave)
      |> Repo.insert()

      IO.puts("Ave registrada: {datos_ave.nombre_comun} ({datos_ave.nombre_cientifico})")

    _ave_existente ->
      IO.puts("El ave ya se encuentra en el catálogo: {datos_ave.nombre_comun}")
  end
end)

IO.puts("¡Catálogo maestro de aves cargado con éxito!")
