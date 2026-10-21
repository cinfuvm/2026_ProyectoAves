defmodule Aves.Moderation do
  @moduledoc """
  Domain for content moderation: reports of photos that do not correspond to a
  bird, and the moderator queue. Backs RF-13 and RF-14.
  """
  use Ash.Domain,
    otp_app: :aves

  resources do
    resource Aves.Moderation.Report
  end
end
