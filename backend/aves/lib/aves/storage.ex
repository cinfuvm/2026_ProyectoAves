defmodule Aves.Storage do
  @moduledoc """
  Stores uploaded sighting photos in a single public folder under a random,
  unique file name, and returns the public URL to save in the database.

  Only JPEG and PNG are accepted, matching the `photo_url` validation of
  `Aves.Bitacora.Sighting`. The format is detected from the first bytes of the
  file, not from the name or the content type sent by the client.

  The folder defaults to `priv/static/uploads` and is served at `/uploads`.
  It can be changed with `config :aves, :uploads_dir`.
  """

  @max_bytes 5 * 1024 * 1024
  @public_prefix "/uploads"

  @doc """
  Copies the upload into the public folder.

  Returns `{:ok, public_url}` or `{:error, message}`, where `message` is in
  Spanish because it is shown to the user.
  """
  def store(%Plug.Upload{path: path}) do
    with :ok <- check_size(path),
         {:ok, bytes} <- File.read(path),
         {:ok, extension} <- detect_extension(bytes) do
      name = Ecto.UUID.generate() <> extension
      File.mkdir_p!(uploads_dir())
      File.cp!(path, Path.join(uploads_dir(), name))

      {:ok, @public_prefix <> "/" <> name}
    end
  end

  @doc "Absolute path of the folder where photos are written."
  def uploads_dir do
    Application.get_env(:aves, :uploads_dir) || Application.app_dir(:aves, "priv/static/uploads")
  end

  defp check_size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size <= @max_bytes -> :ok
      {:ok, _} -> {:error, "La foto supera el tamaño máximo de 5 MB"}
      {:error, _} -> {:error, "No se pudo leer la foto"}
    end
  end

  defp detect_extension(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, ".jpg"}

  defp detect_extension(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: {:ok, ".png"}

  defp detect_extension(_bytes), do: {:error, "La foto debe ser JPEG o PNG"}
end
