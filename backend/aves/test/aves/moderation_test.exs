defmodule Aves.ModerationTest do
  use Aves.DataCase

  alias Aves.Moderation

  describe "reporte" do
    alias Aves.Moderation.Report

    import Aves.ModerationFixtures

    @invalid_attrs %{motivo: nil, fecha_reporte: nil}

    test "list_reporte/0 returns all reporte" do
      report = report_fixture()
      assert Moderation.list_reporte() == [report]
    end

    test "get_report!/1 returns the report with given id" do
      report = report_fixture()
      assert Moderation.get_report!(report.id) == report
    end

    test "create_report/1 with valid data creates a report" do
      valid_attrs = %{motivo: "some motivo", fecha_reporte: ~U[2026-10-15 04:06:00Z]}

      assert {:ok, %Report{} = report} = Moderation.create_report(valid_attrs)
      assert report.motivo == "some motivo"
      assert report.fecha_reporte == ~U[2026-10-15 04:06:00Z]
    end

    test "create_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_report(@invalid_attrs)
    end

    test "update_report/2 with valid data updates the report" do
      report = report_fixture()
      update_attrs = %{motivo: "some updated motivo", fecha_reporte: ~U[2026-10-16 04:06:00Z]}

      assert {:ok, %Report{} = report} = Moderation.update_report(report, update_attrs)
      assert report.motivo == "some updated motivo"
      assert report.fecha_reporte == ~U[2026-10-16 04:06:00Z]
    end

    test "update_report/2 with invalid data returns error changeset" do
      report = report_fixture()
      assert {:error, %Ecto.Changeset{}} = Moderation.update_report(report, @invalid_attrs)
      assert report == Moderation.get_report!(report.id)
    end

    test "delete_report/1 deletes the report" do
      report = report_fixture()
      assert {:ok, %Report{}} = Moderation.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_report!(report.id) end
    end

    test "change_report/1 returns a report changeset" do
      report = report_fixture()
      assert %Ecto.Changeset{} = Moderation.change_report(report)
    end
  end
end
