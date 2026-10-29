defmodule Aves.Bitacora.Changes.RemovePhotoFile do
  @moduledoc """
  Deletes the stored photo of a sighting once the change is committed.

  Used by the `:soft_delete` action. The database row keeps its `photo_url`
  (the sighting stays in the table, hidden by `deleted_at`), but the file is
  removed, so the photo is no longer served. The file is deleted only after the
  transaction succeeds, so a rollback never loses the photo.
  """
  use Ash.Resource.Change

  alias Aves.Storage

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, sighting} <- result do
        Storage.delete(sighting.photo_url)
      end

      result
    end)
  end
end
