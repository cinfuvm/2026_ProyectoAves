defmodule Aves.StorageTest do
  @moduledoc """
  Unit tests for `Aves.Storage.delete/1`: it may only remove files that the
  storage itself created.
  """
  use ExUnit.Case, async: false

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
end
