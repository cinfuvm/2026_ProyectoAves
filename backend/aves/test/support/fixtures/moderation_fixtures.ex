defmodule Aves.ModerationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Aves.Moderation` context.
  """

  @doc """
  Generate a report.
  """
  def report_fixture(attrs \\ %{}) do
    {:ok, report} =
      attrs
      |> Enum.into(%{
        fecha_reporte: ~U[2026-10-15 04:06:00Z],
        motivo: "some motivo"
      })
      |> Aves.Moderation.create_report()

    report
  end
end
