defmodule Aves.CatalogTest do
  use Aves.DataCase

  alias Aves.Catalog

  describe "ave" do
    alias Aves.Catalog.Bird

    import Aves.CatalogFixtures

    @invalid_attrs %{nombre_comun: nil, nombre_cientifico: nil}

    test "list_ave/0 returns all ave" do
      bird = bird_fixture()
      assert Catalog.list_ave() == [bird]
    end

    test "get_bird!/1 returns the bird with given id" do
      bird = bird_fixture()
      assert Catalog.get_bird!(bird.id) == bird
    end

    test "create_bird/1 with valid data creates a bird" do
      valid_attrs = %{nombre_comun: "some nombre_comun", nombre_cientifico: "some nombre_cientifico"}

      assert {:ok, %Bird{} = bird} = Catalog.create_bird(valid_attrs)
      assert bird.nombre_comun == "some nombre_comun"
      assert bird.nombre_cientifico == "some nombre_cientifico"
    end

    test "create_bird/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_bird(@invalid_attrs)
    end

    test "update_bird/2 with valid data updates the bird" do
      bird = bird_fixture()
      update_attrs = %{nombre_comun: "some updated nombre_comun", nombre_cientifico: "some updated nombre_cientifico"}

      assert {:ok, %Bird{} = bird} = Catalog.update_bird(bird, update_attrs)
      assert bird.nombre_comun == "some updated nombre_comun"
      assert bird.nombre_cientifico == "some updated nombre_cientifico"
    end

    test "update_bird/2 with invalid data returns error changeset" do
      bird = bird_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_bird(bird, @invalid_attrs)
      assert bird == Catalog.get_bird!(bird.id)
    end

    test "delete_bird/1 deletes the bird" do
      bird = bird_fixture()
      assert {:ok, %Bird{}} = Catalog.delete_bird(bird)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_bird!(bird.id) end
    end

    test "change_bird/1 returns a bird changeset" do
      bird = bird_fixture()
      assert %Ecto.Changeset{} = Catalog.change_bird(bird)
    end
  end
end
