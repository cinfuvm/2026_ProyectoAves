defmodule AvesWeb.API.ReportControllerTest do
  @moduledoc """
  Request tests for reports and the moderator queue (RF-13, RF-14).
  """
  use AvesWeb.ConnCase

  import Aves.Factory

  alias Aves.Bitacora.Sighting
  alias Aves.Moderation.Report

  describe "POST /api/reports (RF-13)" do
    test "un usuario autenticado reporta una foto", %{conn: conn} do
      {_reporter, token} = user_with_token()
      {other, _} = user_with_token()
      sighting = sighting(other)

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/reports", %{"sighting_id" => sighting.id, "reason" => "No es un ave"})

      assert %{"report" => report} = json_response(conn, 201)
      assert report["sighting_id"] == sighting.id
      assert report["reason"] == "No es un ave"
      assert report["status"] == "pendiente"
    end

    test "sin token devuelve 401", %{conn: conn} do
      conn = post(conn, ~p"/api/reports", %{"sighting_id" => Ecto.UUID.generate()})
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "GET /api/reports (RF-14)" do
    test "un moderador ve la cola de reportes", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_moderator, mod_token} = user_with_token(:moderador)
      sighting = sighting(owner)

      {:ok, _} =
        Ash.create(Report, %{sighting_id: sighting.id, reason: "x"},
          actor: reporter,
          action: :report
        )

      conn =
        conn
        |> sign_in_conn(mod_token)
        |> get(~p"/api/reports")

      assert %{"reports" => reports, "pagination" => _} = json_response(conn, 200)
      assert length(reports) == 1
    end

    test "un usuario normal no ve reportes en la cola (sin fuga de datos)", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_user, token} = user_with_token()
      sighting = sighting(owner)

      {:ok, _} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      conn =
        conn
        |> sign_in_conn(token)
        |> get(~p"/api/reports")

      # Either 403 or an empty list is acceptable: the key is no data leaks.
      case conn.status do
        403 ->
          assert json_response(conn, 403)

        200 ->
          assert %{"reports" => []} = json_response(conn, 200)
      end
    end

    test "filtra por estado", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_moderator, mod_token} = user_with_token(:moderador)
      sighting = sighting(owner)

      {:ok, report} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      {:ok, _} = Ash.update(report, %{}, actor: moderator(), action: :approve)

      conn =
        conn
        |> sign_in_conn(mod_token)
        |> get(~p"/api/reports?status=aprobado")

      assert %{"reports" => reports} = json_response(conn, 200)
      assert length(reports) == 1
      assert hd(reports)["status"] == "aprobado"
    end
  end

  describe "POST /api/reports/:id/approve (RF-14)" do
    test "aprueba un reporte; la foto permanece visible", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_moderator, mod_token} = user_with_token(:moderador)
      sighting = sighting(owner)

      {:ok, report} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      conn =
        conn
        |> sign_in_conn(mod_token)
        |> post(~p"/api/reports/#{report.id}/approve")

      assert %{"report" => updated} = json_response(conn, 200)
      assert updated["status"] == "aprobado"

      reloaded = Ash.get!(Sighting, sighting.id, authorize?: false)
      assert is_nil(reloaded.hidden_at)
    end

    test "un usuario normal no puede aprobar (no autorizado)", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_user, token} = user_with_token()
      sighting = sighting(owner)

      {:ok, report} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/reports/#{report.id}/approve")

      # 403 (forbidden) or 404 (not disclosed) are both acceptable; the report
      # must remain unchanged.
      assert conn.status in [403, 404]
      reloaded = Ash.get!(Report, report.id, authorize?: false)
      assert reloaded.status == :pendiente
    end
  end

  describe "POST /api/reports/:id/retire (RF-14)" do
    test "retira un reporte; la foto queda oculta", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_moderator, mod_token} = user_with_token(:moderador)
      sighting = sighting(owner)

      {:ok, report} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      conn =
        conn
        |> sign_in_conn(mod_token)
        |> post(~p"/api/reports/#{report.id}/retire")

      assert %{"report" => updated} = json_response(conn, 200)
      assert updated["status"] == "retirado"

      reloaded = Ash.get!(Sighting, sighting.id, authorize?: false)
      refute is_nil(reloaded.hidden_at)
    end

    test "un usuario normal no puede retirar (no autorizado)", %{conn: conn} do
      {reporter, _} = user_with_token()
      {owner, _} = user_with_token()
      {_user, token} = user_with_token()
      sighting = sighting(owner)

      {:ok, report} =
        Ash.create(Report, %{sighting_id: sighting.id}, actor: reporter, action: :report)

      conn =
        conn
        |> sign_in_conn(token)
        |> post(~p"/api/reports/#{report.id}/retire")

      assert conn.status in [403, 404]

      reloaded = Ash.get!(Report, report.id, authorize?: false)
      assert reloaded.status == :pendiente

      sighting_reloaded = Ash.get!(Sighting, sighting.id, authorize?: false)
      assert is_nil(sighting_reloaded.hidden_at)
    end
  end
end
