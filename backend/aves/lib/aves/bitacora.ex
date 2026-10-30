defmodule Aves.Bitacora do
  @moduledoc """
  Domain for the personal bird log ("bitácora"): sightings and personal
  collections. Backs RF-08 through RF-12.
  """
  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Bitacora.Sighting
    resource Aves.Bitacora.CollectionItem
  end
end
