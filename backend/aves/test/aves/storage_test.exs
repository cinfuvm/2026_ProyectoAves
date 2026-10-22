defmodule Aves.StorageTest do
  @moduledoc """
  Unit tests for `Aves.Storage.delete/1`: it may only remove files that the
  storage itself created.
  """
  use ExUnit.Case, async: false

  import Aves.Factory

  alias Aves.Storage

  setup context do
    previous = Application.get_env(:aves, :uploads_dir)
    Application.put_env(:aves, :uploads_dir, Path.join(context.tmp_dir, "uploads"))
    File.mkdir_p!(Storage.uploads_dir())

    on_exit(fn -> Application.put_env(:aves, :uploads_dir, previous) end)
    :ok
  end

  @tag :tmp_dir
  test "ignora URLs externas", %{tmp_dir: tmp_dir} do
    outside = Path.join(tmp_dir, "ajena.jpg")
    File.write!(outside, "no es nuestra")

    assert Storage.delete("https://example.com/ajena.jpg") == :ok
    assert File.exists?(outside)
  end

  @tag :tmp_dir
  test "no sale de la carpeta de fotos aunque la URL intente recorrer rutas", %{
    tmp_dir: tmp_dir
  } do
    outside = Path.join(tmp_dir, "secreto.jpg")
    File.write!(outside, "secreto")

    assert Storage.delete("/uploads/../secreto.jpg") == :ok
    assert File.exists?(outside)
  end

  @tag :tmp_dir
  test "borra el archivo de una URL generada por la carpeta de fotos" do
    name = "#{Ecto.UUID.generate()}.png"
    path = Path.join(Storage.uploads_dir(), name)
    File.write!(path, "foto")

    assert Storage.delete("/uploads/" <> name) == :ok
    refute File.exists?(path)
  end

  @tag :tmp_dir
  test "un archivo que ya no existe no es un error" do
    assert Storage.delete("/uploads/#{Ecto.UUID.generate()}.jpg") == :ok
  end

  describe "quitar metadatos (EXIF y similares)" do
    @tag :tmp_dir
    test "un JPEG pierde EXIF con GPS y comentarios, y conserva la imagen", %{tmp_dir: tmp_dir} do
      gps = exif_segment("Exif\0\0GPSLatitude=-33.4")
      comment = comment_segment("cámara: modelo de prueba")
      upload = write_upload(tmp_dir, "ave.jpg", jpeg_bytes(gps <> comment))

      assert {:ok, url} = Storage.store(upload)

      stored = File.read!(Path.join(Storage.uploads_dir(), Path.basename(url)))
      refute stored =~ "GPS"
      refute stored =~ "Exif"
      refute stored =~ "modelo de prueba"
      assert stored =~ "JFIF"
      assert binary_part(stored, 0, 2) == <<0xFF, 0xD8>>
      assert binary_part(stored, byte_size(stored) - 2, 2) == <<0xFF, 0xD9>>
    end

    @tag :tmp_dir
    test "un PNG pierde sus chunks de texto y conserva el resto", %{tmp_dir: tmp_dir} do
      png =
        <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>> <>
          png_chunk("IHDR", <<0::104>>) <>
          png_chunk("tEXt", "GPS=-33.4,-70.6") <>
          png_chunk("IEND", <<>>)

      upload = write_upload(tmp_dir, "ave.png", png)

      assert {:ok, url} = Storage.store(upload)

      stored = File.read!(Path.join(Storage.uploads_dir(), Path.basename(url)))
      refute stored =~ "GPS"
      assert stored =~ "IHDR"
      assert binary_part(stored, byte_size(stored) - 12, 12) == png_chunk("IEND", <<>>)
    end

    @tag :tmp_dir
    test "rechaza un JPEG con un segmento que dice medir más de lo que tiene", %{
      tmp_dir: tmp_dir
    } do
      broken = <<0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, "x">>
      upload = write_upload(tmp_dir, "roto.jpg", broken)

      assert {:error, message} = Storage.store(upload)
      assert message =~ "JPEG válido"
      assert File.ls!(Storage.uploads_dir()) == []
    end
  end

  defp write_upload(dir, name, bytes) do
    path = Path.join(dir, name)
    File.write!(path, bytes)
    %Plug.Upload{path: path, filename: name, content_type: "application/octet-stream"}
  end

  defp png_chunk(type, data) do
    <<byte_size(data)::32>> <> type <> data <> <<0::32>>
  end
end
