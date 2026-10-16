defmodule Aves.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias Aves.Repo

  alias Aves.Catalog.Bird

  @doc """
  Returns the list of ave.

  ## Examples

      iex> list_ave()
      [%Bird{}, ...]

  """
  def list_ave do
    Repo.all(Bird)
  end

  @doc """
  Gets a single bird.

  Raises `Ecto.NoResultsError` if the Bird does not exist.

  ## Examples

      iex> get_bird!(123)
      %Bird{}

      iex> get_bird!(456)
      ** (Ecto.NoResultsError)

  """
  def get_bird!(id), do: Repo.get!(Bird, id)

  @doc """
  Creates a bird.

  ## Examples

      iex> create_bird(%{field: value})
      {:ok, %Bird{}}

      iex> create_bird(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bird(attrs) do
    %Bird{}
    |> Bird.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a bird.

  ## Examples

      iex> update_bird(bird, %{field: new_value})
      {:ok, %Bird{}}

      iex> update_bird(bird, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_bird(%Bird{} = bird, attrs) do
    bird
    |> Bird.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bird.

  ## Examples

      iex> delete_bird(bird)
      {:ok, %Bird{}}

      iex> delete_bird(bird)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bird(%Bird{} = bird) do
    Repo.delete(bird)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bird changes.

  ## Examples

      iex> change_bird(bird)
      %Ecto.Changeset{data: %Bird{}}

  """
  def change_bird(%Bird{} = bird, attrs \\ %{}) do
    Bird.changeset(bird, attrs)
  end

  def ranking_aves do
    Repo.all(from p in Aves.Social.Post, order_by: [desc: p.views_count], preload: [:ave])
  end
end
