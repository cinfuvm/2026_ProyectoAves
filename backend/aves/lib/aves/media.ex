defmodule Aves.Media do
  @moduledoc """
  Dominio Ash del catálogo de fotografías de avistamientos.

  Agrupa los recursos del catálogo público (`Aves.Media.Image`) y de los
  reportes de moderación (`Aves.Media.Report`) que abre la app al marcar una
  foto como inapropiada.
  """

  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Media.Image
    resource Aves.Media.Report
  end
end
