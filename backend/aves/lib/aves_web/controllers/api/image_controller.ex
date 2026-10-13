defmodule AvesWeb.API.ImageController do
  @moduledoc """
  Endpoints del catálogo de fotografías para la app móvil.

  Son controladores a medida y no pasan por Ash JSON-API porque la subida
  llega en `multipart/form-data`, formato que Ash JSON-API no sabe leer. El
  binario se guarda en disco y solo los metadatos viven en la base de datos.

    * `GET  /images`       catálogo público, filtrable y paginado
    * `POST /images`       subida de una foto (bearer)
    * `PUT  /images?id=`   reporte de moderación (bearer)
    * `GET  /images/reports`      lista de reportes (solo `admin`)
    * `PUT  /images/reports/:id`  cambia el estado de uno (solo `admin`)

  El contrato que responde es el de `birds_apis.yaml`, que es el que parsean
  `PaginaFotos` y `FotoPublica` de la app. La ruta de reportes no forma parte
  de ese contrato: es una extensión propia para la pantalla de moderación.
  """

  use AvesWeb, :controller

  alias Aves.Media.{Image, Report, Subidas}

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

  # Estados que la app puede ponerle a un reporte. Igual motivo que @motivos:
  # mapeo explícito, nunca `String.to_existing_atom`.
  @estados %{"abierto" => :abierto, "revisado" => :revisado, "descartado" => :descartado}

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

  @doc """
  GET /images/reports - Lista los reportes con su foto.

  Reservado a `admin`: cada fila lleva el texto que escribió quien reportó y
  su nombre. Acepta `?estado=` para quedarse con `abierto`, `revisado`,
  `descartado` o `todos`.
  """
  def list_reports(conn, params) do
    with :ok <- solo_admin(conn),
         {:ok, filtro} <- filtro_estado(params["estado"]),
         {:ok, reportes} <- leer_reportes(conn, filtro),
         {:ok, con_contexto} <- cargar_contexto(reportes, conn) do
      json(conn, %{reportes: Enum.map(con_contexto, &reporte_moderacion_json/1)})
    else
      {:error, :no_autorizado, mensaje} -> error(conn, :forbidden, mensaje)
      {:error, mensaje} -> error(conn, :bad_request, mensaje)
    end
  end

  @doc "PUT /images/reports/:id - Cambia el estado de un reporte. Solo `admin`."
  def update_report(conn, params) do
    with :ok <- solo_admin(conn),
         {:ok, estado} <- validar_estado(params["estado"]),
         {:ok, reporte} <- buscar_reporte(conn, params["id"]),
         {:ok, actualizado} <- poner_estado(conn, reporte, estado),
         {:ok, [con_contexto]} <- cargar_contexto([actualizado], conn) do
      conn
      |> put_status(:ok)
      |> json(reporte_moderacion_json(con_contexto))
    else
      {:error, :no_autorizado, mensaje} -> error(conn, :forbidden, mensaje)
      {:error, :no_encontrado, mensaje} -> error(conn, :not_found, mensaje)
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
    destinos = Enum.map(Subidas.carpetas(), &Path.join(&1, nombre))

    case escribir(archivo.path, destinos, []) do
      {:ok, escritos} ->
        crear_registro(conn, params, archivo, nombre, escritos)

      {:error, motivo, escritos} ->
        borrar(escritos)
        {:error, motivo}
    end
  end

  # Copia el archivo a las carpetas de `Aves.Media.Subidas`. Si alguna falla,
  # se borran las copias ya hechas para no dejar huérfanos.
  defp escribir(origen, [destino | resto], escritos) do
    case escribir_uno(origen, destino) do
      :ok -> escribir(origen, resto, [destino | escritos])
      {:error, motivo} -> {:error, motivo, escritos}
    end
  end

  defp escribir(_origen, [], escritos), do: {:ok, Enum.reverse(escritos)}

  defp escribir_uno(origen, destino) do
    case preparar_destino(destino) do
      :ok ->
        case File.cp(origen, destino) do
          :ok -> :ok
          {:error, posix} -> {:error, "No se pudo guardar el archivo: #{posix}"}
        end

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  defp preparar_destino(destino) do
    case File.mkdir_p(Path.dirname(destino)) do
      :ok -> :ok
      {:error, posix, _archivo} -> {:error, "No se pudo crear el almacén: #{posix}"}
      {:error, posix} -> {:error, "No se pudo crear el almacén: #{posix}"}
    end
  end

  defp crear_registro(conn, params, archivo, nombre, escritos) do
    attrs = %{
      ruta: Path.join("uploads", nombre),
      url: url_publica(nombre),
      categoria: params["categoria"] || "sin categoria",
      mime: archivo.content_type,
      tamano: File.stat!(List.first(escritos)).size,
      lugar: params["lugar"],
      fecha: params["fecha"],
      comentario: params["comentario"],
      autor_id: actor(conn).id,
      autor_nombre: actor(conn).username
    }

    case Ash.create(Image, attrs, actor: actor(conn), authorize?: true) do
      {:ok, imagen} ->
        {:ok, imagen}

      {:error, error} ->
        # Los ficheros ya estaban en disco: no dejamos huérfanos si el
        # registro no se pudo guardar.
        borrar(escritos)
        {:error, mensaje(error)}
    end
  end

  defp borrar(archivos), do: Enum.each(archivos, &File.rm/1)

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

  # --- Moderación -----------------------------------------------------------

  # El router ya exige un bearer válido; el rol es la segunda puerta, y este
  # es el mensaje que verá la app en el 403.
  defp solo_admin(conn) do
    case actor(conn) do
      %{rol: :admin} -> :ok
      _ -> {:error, :no_autorizado, "Solo un administrador puede moderar reportes."}
    end
  end

  # `?estado=` vacío o `todos` deja el listado completo.
  defp filtro_estado(valor) when is_binary(valor) do
    case String.trim(valor) do
      "" -> {:ok, nil}
      "todos" -> {:ok, nil}
      otro -> estado_desde_mapa(otro)
    end
  end

  defp filtro_estado(_valor), do: {:ok, nil}

  # En cambio al cambiar el estado sí hace falta mandarlo.
  defp validar_estado(valor) when is_binary(valor) do
    case String.trim(valor) do
      "" -> {:error, "Falta el estado del reporte."}
      otro -> estado_desde_mapa(otro)
    end
  end

  defp validar_estado(_valor), do: {:error, "Falta el estado del reporte."}

  defp estado_desde_mapa(otro) do
    case Map.fetch(@estados, otro) do
      {:ok, estado} -> {:ok, estado}
      :error -> {:error, "Estado no reconocido: #{otro}."}
    end
  end

  defp leer_reportes(conn, filtro) do
    Report
    |> filtrar_estado(filtro)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read(actor: actor(conn), authorize?: true)
    |> case do
      {:ok, reportes} -> {:ok, reportes}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

  defp filtrar_estado(query, nil), do: query

  defp filtrar_estado(query, valor) do
    Ash.Query.filter(query, estado == ^valor)
  end

  defp buscar_reporte(conn, id) do
    case Ash.get(Report, id, actor: actor(conn), authorize?: true) do
      {:ok, %Report{} = reporte} ->
        {:ok, reporte}

      {:error, error} ->
        if no_encontrado?(error) do
          {:error, :no_encontrado, "El reporte no existe."}
        else
          {:error, mensaje(error)}
        end
    end
  end

  defp poner_estado(conn, reporte, estado) do
    case Ash.update(reporte, %{estado: estado}, actor: actor(conn), authorize?: true) do
      {:ok, actualizado} -> {:ok, actualizado}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

  # La foto y el usuario solo sirven para pintar la fila de moderación: el
  # reporte ya se ha autorizado, así que se cargan sin volver a pasar por las
  # políticas (la de `User` no deja leer sus filas fuera del propio login).
  defp cargar_contexto(reportes, conn) do
    opciones = [actor: actor(conn), authorize?: false]

    case Ash.load(reportes, [:avistamiento, :reportado_por], opciones) do
      {:ok, cargados} -> {:ok, cargados}
      {:error, error} -> {:error, mensaje(error)}
    end
  end

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

  # Forma que lee la pantalla de moderación: el reporte con su foto al lado
  # y el nombre de quien lo abrió, que no sale en `reporte_json/1` porque ese
  # JSON es el que ya consume la app al abrirlo.
  defp reporte_moderacion_json(reporte) do
    %{
      id: reporte.id,
      motivo: reporte.motivo,
      detalle: reporte.detalle,
      estado: reporte.estado,
      creado_en: reporte.inserted_at,
      reportado_por: usuario_nombre(reporte.reportado_por),
      avistamiento: imagen_moderacion_json(reporte.avistamiento)
    }
  end

  # Si la foto se borró mientras el reporte seguía abierto, se deja la fila
  # con `avistamiento: null` en vez de romper el listado entero.
  defp imagen_moderacion_json(%Image{} = imagen) do
    %{
      id: imagen.id,
      url: imagen.url,
      categoria: imagen.categoria,
      autor: imagen.autor_nombre,
      lugar: imagen.lugar,
      fecha: imagen.fecha,
      comentario: imagen.comentario
    }
  end

  defp imagen_moderacion_json(_imagen), do: nil

  defp usuario_nombre(%{username: username}), do: to_string(username)
  defp usuario_nombre(_autor), do: nil

  # --- Utilidades ------------------------------------------------------------

  defp actor(conn), do: Ash.PlugHelpers.get_actor(conn)

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
