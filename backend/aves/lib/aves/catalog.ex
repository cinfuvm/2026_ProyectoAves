defmodule Aves.Catalog do
  @moduledoc """
  Domain for the bird catalog: categories and birds.

  Only the minimal resources required by the sightings/collection/moderation
  requirements (RF-08..RF-14) live here. The full bird CRUD (RF-05) and search
  (RF-06) are handled in their own issues.
  """
  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Catalog.Category
    resource Aves.Catalog.Bird
    resource Aves.Catalog.BirdView
  end
end
