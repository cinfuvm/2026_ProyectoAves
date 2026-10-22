defmodule Aves.Catalog do
  @moduledoc """
  Domain for the bird catalog: categories, birds and the view counter used for
  popular birds (RF-15).
  """
  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Catalog.Category
    resource Aves.Catalog.Bird
    resource Aves.Catalog.BirdView
  end
end
