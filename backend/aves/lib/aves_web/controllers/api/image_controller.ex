defmodule AvesWeb.API.ImageController do
  @moduledoc """
  Endpoints del catálogo de fotografías para la app móvil.

  Son controladores a medida y no pasan por Ash JSON-API porque la subida
  llega en `multipart/form-data`, formato que Ash JSON-API no sabe leer. El
  binario se guarda en disco y solo los metadatos viven en la base de datos.

    * `GET  /images`       catálogo público, filtrable y paginado
    * `POST /images`       subida de una foto (bearer)
    * `PUT  /images?id=`   reporte de moderación (bearer)

  El contrato que responde es el de `birds_apis.yaml`, que es el que parsean
  `PaginaFotos` y `FotoPublica` de la app.
  """

  use AvesWeb, :controller

  alias Aves.Media.{Image, Report}

  # `Ash.Query.filter/2` es una macro, así que hay que requerir el módulo.
  require Ash.Query

  # Tope de subida: el contrato contempla un `413` para archivos grandes.
  @maximo_bytes 10 * 1024 * 1024

  # Extensiones admitidas, indexadas por el `content-type` que declara el
  # cliente. Sirven a la vez para validar el formato y nombrar el fichero.
  @extensiones %{
    "image/jpeg" => "jpg",
    "image/png" => "png",
    "image/webp" => "webp",
    "image/gif" => "gif"
  }

  # Códigos que la app envía, con su átomo de contrapartida. Se mapea de forma
  # explícita en vez de con `String.to_existing_atom` para no depender de que
  # esos átomas ya estén cargados en la VM.
  @motivos %{
    "no_es_ave" => :no_es_ave,
    "contenido_ofensivo" => :contenido_ofensivo,
    "imagen_enganosa" => :imagen_enganosa,
    "derechos_autor" => :derechos_autor,
    "otro" => :otro
  }

  @doc "GET /images - Devuelve una página del catálogo. Es público."
  def index(conn, params) do
    with {:ok, pagina, por_pagina} <- paginacion(params),
         {:ok, filtro} <- filtro_categoria(params["categoria"]),
         {:ok, imagenes} <- leer_pagina(filtro, pagina, por_pagina),
         {:ok, total} <- contar(filtro) do
      json(conn, %{
        urls: Enum.map(imagenes, &imagen_json/1),
        paginado: %{pagina: pagina, total: total_paginas(total, por_pagina)}
      })
    else
      {:error, mensaje} -> error(conn, :bad_request, mensaje)
    end
  end

  @doc "POST /images - Sube una fotografía de avistamiento."
  def create(conn, params) do
    case subir(conn, params) do
      {:ok, imagen} ->
        conn
        |> put_status(:created)
        |> json(imagen_json(imagen))

      {:error, :demasiado_grande} ->
        error(conn, :payload_too_large, "La imagen supera el tamaño máximo permitido.")

      {:error, mensaje} ->
        error(conn, :bad_request, mensaje)
    end
  end

  @doc "PUT /images?id= - Abre un reporte de moderación sobre una foto."
  def report(conn, params) do
    with {:ok, id} <- texto(params["id"], "Falta el identificador de la foto."),
         {:ok, motivo} <- validar_motivo(params["motivo"]),
         {:ok, imagen} <- buscar_imagen(id),
         {:ok, reporte} <- abrir_reporte(conn, imagen, motivo, params["detalle"]) do
      conn
      |> put_status(:ok)
      |> json(reporte_json(reporte))
    else
      {:error, :no_encontrada, mensaje} -> error(conn, :not_found, mensaje)
      {:error, mensaje} -> error(conn, :bad_request, mensaje)
    end
  end

  # --- Catálogo -------------------------------------------------------------

  defp leer_pagina(filtro, pagina, por_pagina) do
    Image
    |> filtrar(filtro)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(por_pagina)
    |> Ash.Query.offset(pagina * por_pagina)
    |> Ash.read()
    |> case do
      {:ok, imagenes} -> {:ok, imagenes}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

  defp contar(filtro) do
    Image
    |> filtrar(filtro)
    |> Ash.count()
    |> case do
      {:ok, total} -> {:ok, total}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

  # Devuelve una query filtrada, o sin filtrar cuando no hay categoría.
  defp filtrar(query, nil), do: query

  defp filtrar(query, valor) do
    Ash.Query.filter(query, categoria == ^valor)
  end

  # `"Todas"` es como la app pide el catálogo completo, así que no filtra.
  defp filtro_categoria(nil), do: {:ok, nil}

  defp filtro_categoria(categoria) do
    case String.trim(categoria) do
      "" -> {:ok, nil}
      "Todas" -> {:ok, nil}
      otra -> {:ok, otra}
    end
  end

  defp paginacion(params) do
    pagina = entero(params["pagina"], 0)
    por_pagina = entero(params["por_pagina"], 20)

    cond do
      pagina < 0 -> {:error, "`pagina` no puede ser negativa."}
      por_pagina < 1 -> {:error, "`por_pagina` debe ser al menos 1."}
      por_pagina > 50 -> {:error, "`por_pagina` no puede superar 50."}
      true -> {:ok, pagina, por_pagina}
    end
  end

  defp total_paginas(0, _por_pagina), do: 0
  defp total_paginas(total, por_pagina), do: ceil(total / por_pagina)

  # --- Subida ---------------------------------------------------------------

  defp subir(conn, params) do
    case validar_archivo(params["file"]) do
      {:ok, extension} -> guardar(conn, params, extension)
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp validar_archivo(%Plug.Upload{} = archivo) do
    case File.stat(archivo.path) do
      {:ok, %File.Stat{size: 0}} ->
        {:error, "El archivo está vacío."}

      {:ok, %File.Stat{size: size}} when size > @maximo_bytes ->
        {:error, :demasiado_grande}

      {:ok, _estadistica} ->
        case Map.fetch(@extensiones, archivo.content_type) do
          {:ok, extension} -> {:ok, extension}
          :error -> {:error, "Formato no admitido: usa JPEG, PNG, WebP o GIF."}
        end

      {:error, _posix} ->
        {:error, "No se pudo leer el archivo subido."}
    end
  end

  defp validar_archivo(_), do: {:error, "Falta el archivo en el campo `file`."}

  defp guardar(conn, params, extension) do
    archivo = params["file"]
    nombre = "#{Ecto.UUID.generate()}.#{extension}"
    destino = Path.join(ruta_subidas(), nombre)

    case preparar_destino(destino) do
      :ok ->
        case File.cp(archivo.path, destino) do
          :ok -> crear_registro(conn, params, archivo, nombre, destino)
          {:error, posix} -> {:error, "No se pudo guardar el archivo: #{posix}"}
        end

      {:error, mensaje} ->
        {:error, mensaje}
    end
  end

  defp preparar_destino(destino) do
    case File.mkdir_p(Path.dirname(destino)) do
      :ok -> :ok
      {:error, posix, _archivo} -> {:error, "No se pudo crear el almacén: #{posix}"}
      {:error, posix} -> {:error, "No se pudo crear el almacén: #{posix}"}
    end
  end

  defp crear_registro(conn, params, archivo, nombre, destino) do
    attrs = %{
      ruta: Path.join("uploads", nombre),
      url: url_publica(nombre),
      categoria: params["categoria"] || "sin categoria",
      mime: archivo.content_type,
      tamano: File.stat!(destino).size,
      lugar: params["lugar"],
      fecha: params["fecha"],
      comentario: params["comentario"],
      autor_id: actor(conn).id,
      autor_nombre: actor(conn).nickname
    }

    case Ash.create(Image, attrs, actor: actor(conn), authorize?: true) do
      {:ok, imagen} ->
        {:ok, imagen}

      {:error, error} ->
        # El fichero ya estaba en disco: no dejamos huérfanos si el registro
        # no se pudo guardar.
        File.rm(destino)
        {:error, mensaje(error)}
    end
  end

  # --- Reportes -------------------------------------------------------------

  defp abrir_reporte(conn, imagen, motivo, detalle) do
    attrs = %{
      avistamiento_id: imagen.id,
      reportado_por_id: actor(conn).id,
      motivo: Map.fetch!(@motivos, motivo),
      detalle: detalle
    }

    case Ash.create(Report, attrs, actor: actor(conn), authorize?: true) do
      {:ok, reporte} -> {:ok, reporte}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

  defp validar_motivo(motivo) do
    cond do
      motivo in [nil, ""] -> {:error, "Falta el motivo del reporte."}
      not Map.has_key?(@motivos, motivo) -> {:error, "Motivo no reconocido: #{motivo}."}
      true -> {:ok, motivo}
    end
  end

  defp buscar_imagen(id) do
    case Ash.get(Image, id, authorize?: false) do
      {:ok, %Image{} = imagen} ->
        {:ok, imagen}

      {:error, error} ->
        if no_encontrado?(error) do
          {:error, :no_encontrada, "La fotografía no existe."}
        else
          {:error, mensaje(error)}
        end
    end
  end

  # `Ash.get/3` no devuelve `{:ok, nil}`: expide un `Ash.Error.Query.NotFound`
  # envuelto en un `Ash.Error.Invalid`.
  defp no_encontrado?(%Ash.Error.Invalid{errors: errores}),
    do: Enum.any?(errores, &no_encontrado?/1)

  defp no_encontrado?(%Ash.Error.Query.NotFound{}), do: true
  defp no_encontrado?(_), do: false

  # --- Serialización --------------------------------------------------------

  defp imagen_json(imagen) do
    %{
      id: imagen.id,
      url: imagen.url,
      categoria: imagen.categoria,
      autor: imagen.autor_nombre,
      lugar: imagen.lugar,
      fecha: imagen.fecha,
      comentario: imagen.comentario,
      subida_en: imagen.inserted_at
    }
  end

  defp reporte_json(reporte) do
    %{
      id: reporte.id,
      avistamiento_id: reporte.avistamiento_id,
      motivo: reporte.motivo,
      detalle: reporte.detalle,
      estado: reporte.estado,
      creado_en: reporte.inserted_at
    }
  end

  # --- Utilidades ------------------------------------------------------------

  defp actor(conn), do: Ash.PlugHelpers.get_actor(conn)

  defp ruta_subidas, do: Application.app_dir(:aves, "priv/static/uploads")

  defp url_publica(nombre), do: Path.join([base_url_publica(), "uploads", nombre])

  # Se lee de la config (no directamente del entorno) para poder cambiarla sin
  # tocar el código: ver `:url_publica` en `config/runtime.exs`.
  defp base_url_publica, do: Application.get_env(:aves, :url_publica, "http://127.0.0.1:4001")

  defp texto(valor, _mensaje) when is_binary(valor) and byte_size(valor) > 0, do: {:ok, valor}
  defp texto(_valor, mensaje), do: {:error, mensaje}

  defp entero(valor, predeterminado) when is_binary(valor) do
    case Integer.parse(valor) do
      {numero, _resto} -> numero
      :error -> predeterminado
    end
  end

  defp entero(_valor, predeterminado), do: predeterminado

  defp error(conn, codigo, mensaje), do: conn |> put_status(codigo) |> json(%{error: mensaje})

  defp mensaje(%Ash.Error.Invalid{errors: errores}) do
    Enum.map_join(errores, ", ", &Exception.message/1)
  end

  defp mensaje(erro), do: Exception.message(erro)
end
