defmodule Aves.SocialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Aves.Social` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        fecha_creacion: ~U[2026-10-15 02:26:00Z],
        pie_de_foto: "some pie_de_foto",
        url_imagen: "some url_imagen",
        views_count: 42
      })
      |> Aves.Social.create_post()

    post
  end

  @doc """
  Generate a like.
  """
  def like_fixture(attrs \\ %{}) do
    {:ok, like} =
      attrs
      |> Enum.into(%{
        fecha_like: ~U[2026-10-15 02:41:00Z]
      })
      |> Aves.Social.create_like()

    like
  end
end
