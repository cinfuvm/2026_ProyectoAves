defmodule Aves.Media.Subidas do
  @moduledoc """
  Carpetas donde viven las fotos subidas por `POST /images`.

  El binario no se guarda en la base de datos: se copia a disco y solo los
  metadatos viajan en Postgres. Este módulo es la única fuente de verdad de
  esas carpetas, para que el controlador y la tarea `mix aves.limpiar_subidas`
  no tengan que acordarse por separado.
  """

  @doc """
  Carpetas donde escribir cada foto.

  `Plug.Static` sirve `/uploads` desde `Application.app_dir`, que en Unix es
  un enlace simbólico a `priv/static` pero en Windows una **copia**: si se
  limpia `_build`, la copia desaparece mientras el registro sigue en la base
  de datos, y la app acaba listando fotos cuya imagen ya no carga.

  Por eso cada foto se guarda también en el `priv/static/uploads` de origen,
  que es el que sobrevive. Como `mix compile` copia `priv/` a `_build`, tras
  una limpieza las fotos se recuperan solas al recompilar.

  En un release no hay checkout de origen, así que solo se usa la carpeta
  servida.
  """
  @spec carpetas() :: [Path.t()]
  def carpetas do
    [servida() | List.wrap(origen())]
  end

  @doc "Carpeta que `Plug.Static` sirve bajo `/uploads`."
  @spec servida() :: Path.t()
  def servida, do: Application.app_dir(:aves, "priv/static/uploads")

  @doc """
  Carpeta de origen dentro del proyecto, o `nil` si no estamos en un
  checkout de código (por ejemplo, en un release).
  """
  @spec origen() :: Path.t() | nil
  def origen do
    raiz = Path.expand("../../..", __DIR__)

    if File.exists?(Path.join(raiz, "mix.exs")) do
      Path.join(raiz, "priv/static/uploads")
    end
  end
end
