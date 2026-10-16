defmodule Aves.SocialTest do
  use Aves.DataCase

  alias Aves.Social

  describe "publicacion" do
    alias Aves.Social.Post

    import Aves.SocialFixtures

    @invalid_attrs %{url_imagen: nil, pie_de_foto: nil, views_count: nil, fecha_creacion: nil}

    test "list_publicacion/0 returns all publicacion" do
      post = post_fixture()
      assert Social.list_publicacion() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Social.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{url_imagen: "some url_imagen", pie_de_foto: "some pie_de_foto", views_count: 42, fecha_creacion: ~U[2026-10-15 02:26:00Z]}

      assert {:ok, %Post{} = post} = Social.create_post(valid_attrs)
      assert post.url_imagen == "some url_imagen"
      assert post.pie_de_foto == "some pie_de_foto"
      assert post.views_count == 42
      assert post.fecha_creacion == ~U[2026-10-15 02:26:00Z]
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Social.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{url_imagen: "some updated url_imagen", pie_de_foto: "some updated pie_de_foto", views_count: 43, fecha_creacion: ~U[2026-10-16 02:26:00Z]}

      assert {:ok, %Post{} = post} = Social.update_post(post, update_attrs)
      assert post.url_imagen == "some updated url_imagen"
      assert post.pie_de_foto == "some updated pie_de_foto"
      assert post.views_count == 43
      assert post.fecha_creacion == ~U[2026-10-16 02:26:00Z]
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Social.update_post(post, @invalid_attrs)
      assert post == Social.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Social.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Social.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Social.change_post(post)
    end
  end

  describe "like" do
    alias Aves.Social.Like

    import Aves.SocialFixtures

    @invalid_attrs %{fecha_like: nil}

    test "list_like/0 returns all like" do
      like = like_fixture()
      assert Social.list_like() == [like]
    end

    test "get_like!/1 returns the like with given id" do
      like = like_fixture()
      assert Social.get_like!(like.id) == like
    end

    test "create_like/1 with valid data creates a like" do
      valid_attrs = %{fecha_like: ~U[2026-10-15 02:41:00Z]}

      assert {:ok, %Like{} = like} = Social.create_like(valid_attrs)
      assert like.fecha_like == ~U[2026-10-15 02:41:00Z]
    end

    test "create_like/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Social.create_like(@invalid_attrs)
    end

    test "update_like/2 with valid data updates the like" do
      like = like_fixture()
      update_attrs = %{fecha_like: ~U[2026-10-16 02:41:00Z]}

      assert {:ok, %Like{} = like} = Social.update_like(like, update_attrs)
      assert like.fecha_like == ~U[2026-10-16 02:41:00Z]
    end

    test "update_like/2 with invalid data returns error changeset" do
      like = like_fixture()
      assert {:error, %Ecto.Changeset{}} = Social.update_like(like, @invalid_attrs)
      assert like == Social.get_like!(like.id)
    end

    test "delete_like/1 deletes the like" do
      like = like_fixture()
      assert {:ok, %Like{}} = Social.delete_like(like)
      assert_raise Ecto.NoResultsError, fn -> Social.get_like!(like.id) end
    end

    test "change_like/1 returns a like changeset" do
      like = like_fixture()
      assert %Ecto.Changeset{} = Social.change_like(like)
    end
  end
end
