defmodule Aves.Storage do
  @moduledoc """
  Stores uploaded sighting photos in a single public folder under a random,
  unique file name, and returns the public URL to save in the database.

  Only JPEG and PNG are accepted, matching the `photo_url` validation of
  `Aves.Bitacora.Sighting`. The format is detected from the first bytes of the
  file, not from the name or the content type sent by the client.

  Metadata is removed before the file is written. Phone photos often carry
  EXIF data with GPS coordinates, camera serial numbers and dates, so the
  stored copy keeps only what is needed to show the image.

  The folder defaults to `priv/static/uploads` and is served at `/uploads`.
  It can be changed with `config :aves, :uploads_dir`.
  """

  @max_bytes 5 * 1024 * 1024
  @public_prefix "/uploads"
  @png_text_chunks ~w(eXIf tEXt zTXt iTXt tIME)

  @doc """
  Copies the upload into the public folder, without metadata.

  Returns `{:ok, public_url}` or `{:error, message}`, where `message` is in
  Spanish because it is shown to the user.
  """
  def store(%Plug.Upload{path: path}) do
    with :ok <- check_size(path),
         {:ok, bytes} <- File.read(path),
         {:ok, extension} <- detect_extension(bytes),
         {:ok, clean} <- strip_metadata(bytes, extension) do
      name = Ecto.UUID.generate() <> extension
      File.mkdir_p!(uploads_dir())
      File.write!(Path.join(uploads_dir(), name), clean)

      {:ok, @public_prefix <> "/" <> name}
    end
  end

  @doc """
  Deletes the file behind a URL returned by `store/1`.

  Only URLs with the exact shape this module generates are touched. Anything
  else (an external link, a malformed path) is ignored, so a stored value can
  never make the delete reach outside the photos folder. A missing file is not
  an error.
  """
  def delete(url) when is_binary(url) do
    case Regex.run(~r"\A/uploads/([0-9a-f-]{36}\.(?:jpg|png))\z", url) do
      [_, name] -> _ = File.rm(Path.join(uploads_dir(), name))
      nil -> :ok
    end

    :ok
  end

  def delete(_url), do: :ok

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

  # JPEG: walks the segments after SOI. Application segments APP1 to APP15
  # (EXIF, XMP, ...) and comments (COM) are dropped. APP0 (JFIF) and APP2 (ICC
  # color profile) are kept. From the start of the scan (SOS) on, the image
  # data is copied as is.
  defp strip_metadata(<<0xFF, 0xD8, segments::binary>>, ".jpg") do
    case jpeg_segments(segments, [<<0xFF, 0xD8>>]) do
      {:ok, parts} -> {:ok, IO.iodata_to_binary(parts)}
      :error -> {:error, "La foto no es un JPEG válido"}
    end
  end

  # PNG: walks the chunks after the signature. Text chunks and EXIF chunks are
  # dropped; the rest is kept, up to and including IEND.
  defp strip_metadata(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, chunks::binary>>, ".png") do
    case png_chunks(chunks, []) do
      {:ok, parts} ->
        {:ok, IO.iodata_to_binary([<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>> | parts])}

      :error ->
        {:error, "La foto no es un PNG válido"}
    end
  end

  defp strip_metadata(_bytes, _extension), do: {:error, "La foto no es válida"}

  defp jpeg_segments(<<0xFF, 0xDA, _::binary>> = scan, acc),
    do: {:ok, Enum.reverse([scan | acc])}

  defp jpeg_segments(<<0xFF, 0xD9, _::binary>> = eoi, acc),
    do: {:ok, Enum.reverse([eoi | acc])}

  # Markers without a length: restart markers and fill bytes.
  defp jpeg_segments(<<0xFF, marker, rest::binary>>, acc)
       when marker in 0xD0..0xD7 or marker == 0x01,
       do: jpeg_segments(rest, [<<0xFF, marker>> | acc])

  defp jpeg_segments(<<0xFF, marker, length::16, _::binary>> = bin, acc) when length >= 2 do
    size = 2 + length

    case bin do
      <<segment::binary-size(^size), rest::binary>> ->
        if metadata_marker?(marker),
          do: jpeg_segments(rest, acc),
          else: jpeg_segments(rest, [segment | acc])

      _ ->
        :error
    end
  end

  defp jpeg_segments(_bytes, _acc), do: :error

  defp metadata_marker?(marker), do: marker in 0xE1..0xEF or marker == 0xFE

  defp png_chunks(
         <<length::32, type::binary-size(4), _::binary-size(length), _crc::binary-size(4),
           rest::binary>> = bin,
         acc
       ) do
    chunk = binary_part(bin, 0, 12 + length)

    cond do
      type == "IEND" -> {:ok, Enum.reverse([chunk | acc])}
      type in @png_text_chunks -> png_chunks(rest, acc)
      true -> png_chunks(rest, [chunk | acc])
    end
  end

  defp png_chunks(_bytes, _acc), do: :error
end
