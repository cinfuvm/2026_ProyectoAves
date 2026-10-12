defmodule Mix.Tasks.Aves.LimpiarSubidas do
  @shortdoc "Vacía el catálogo de fotos subidas por /images"

  @moduledoc """
  Borra todas las fotos del catálogo, sus reportes de moderación y los
  ficheros subidos en disco.

      mix aves.limpiar_subidas
      mix aves.limpiar_subidas --dry-run

  `--dry-run` solo informa de lo que se borraría, sin tocar nada.

  Antes de borrar, avisa de los registros cuya foto ya no está en disco: es lo
  que queda cuando se limpia `_build`, porque la copia que sirve `Plug.Static`
  vive dentro de esa carpeta (ver `Aves.Media.Subidas`).
  """

  use Mix.Task

  alias Aves.Media.Subidas

  @switches [dry_run: :boolean]

  @impl Mix.Task
  def run(argv) do
    # `strict:` (y no `switches:`) para que las opciones desconocidas salgan
    # en la lista de inválidas en vez de descartarse en silencio.
    {opciones, _resto, invalidos} = OptionParser.parse(argv, strict: @switches)

    case invalidos do
      [] ->
        :ok

      _ ->
        Mix.raise(
          "Opción desconocida: #{inspect(invalidos)}. " <>
            "Usa `mix help aves.limpiar_subidas` para ver las disponibles."
        )
    end

    Mix.Task.run("app.start")

    solo_mirar? = Keyword.get(opciones, :dry_run, false)

    imagenes = contar("images")
    reportes = contar("image_reports")
    ficheros = Enum.flat_map(Subidas.carpetas(), &ficheros/1)
    rotas = imagenes_rotas(ficheros)

    if rotas > 0 do
      Mix.shell().info("Aviso: #{rotas} fotos siguen en la base pero su fichero ya no está.")
    end

    if solo_mirar? do
      Mix.shell().info(
        "Se borrarían #{imagenes} fotos, #{reportes} reportes y #{length(ficheros)} ficheros."
      )
    else
      Aves.Repo.query!("DELETE FROM image_reports")
      Aves.Repo.query!("DELETE FROM images")
      Enum.each(ficheros, &File.rm/1)

      Mix.shell().info(
        "Borradas #{imagenes} fotos, #{reportes} reportes y #{length(ficheros)} ficheros."
      )
    end

    :ok
  end

  defp contar(tabla) do
    %{rows: [[total]]} = Aves.Repo.query!("SELECT count(*) FROM #{tabla}")
    total
  end

  defp ficheros(carpeta) do
    carpeta
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
  end

  # Registros que apuntan a un fichero que ya no existe en ninguna carpeta.
  defp imagenes_rotas(ficheros) do
    nombres =
      ficheros
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    %{rows: filas} = Aves.Repo.query!("SELECT ruta FROM images")

    Enum.count(filas, fn [ruta] ->
      not MapSet.member?(nombres, Path.basename(ruta))
    end)
  end
end
