defmodule LandingWeb.ModeratorLive.Index do
  use LandingWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    reports = [
      %{id: 1, photo_id: 132, photo_url: nil, reason: "Contenido inapropiado", reporter: "Juan Pérez", date: "2026-10-20", priority: "Alta", status: "Pendiente", resolution: nil},
      %{id: 2, photo_id: 221, photo_url: nil, reason: "Fotografía incorrecta", reporter: "Daniela Ruiz", date: "2026-10-21", priority: "Media", status: "Pendiente", resolution: nil},
      %{id: 3, photo_id: 244, photo_url: nil, reason: "Posible spam", reporter: "Pedro Silva", date: "2026-10-22", priority: "Baja", status: "Pendiente", resolution: nil}
    ]

    {:ok, assign(socket, page_title: "Moderación de fotografías", reports: reports, selected_report: nil, tab: "pending")}
  end

  @impl true
  def handle_event("select_report", %{"id" => id}, socket) do
    report = Enum.find(socket.assigns.reports, &(&1.id == String.to_integer(id)))
    {:noreply, assign(socket, selected_report: report)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) when tab in ["pending", "history"] do
    {:noreply, assign(socket, tab: tab, selected_report: nil)}
  end

  @impl true
  def handle_event("resolve", %{"id" => id, "action" => action}, socket)
      when action in ["approve", "remove"] do
    report_id = String.to_integer(id)
    report = Enum.find(socket.assigns.reports, &(&1.id == report_id))

    if report && report.status == "Pendiente" do
      {resolution, notice} =
        case action do
          "approve" -> {"Aprobada", "Reporte resuelto: fotografía aprobada."}
          "remove" -> {"Retirada", "Reporte resuelto: fotografía marcada como retirada."}
        end

      reports =
        Enum.map(socket.assigns.reports, fn item ->
          if item.id == report_id, do: %{item | status: "Resuelto", resolution: resolution}, else: item
        end)

      {:noreply,
       socket
       |> assign(reports: reports, selected_report: nil)
       |> put_flash(:info, notice)}
    else
      {:noreply, put_flash(socket, :error, "El reporte ya fue resuelto o no existe.")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :visible_reports, Enum.filter(assigns.reports, fn report ->
      if assigns.tab == "pending", do: report.status == "Pendiente", else: report.status == "Resuelto"
    end))

    ~H"""
    <Layouts.app flash={@flash} wide={true}>
      <div class="min-h-screen bg-slate-950 text-white">
        <div class="mx-auto max-w-6xl px-5 py-8">
          <header class="mb-7">
            <p class="text-sm font-medium text-indigo-400">RF-14 · Moderación de fotografías</p>
            <h1 class="mt-1 text-3xl font-semibold">Cola de reportes</h1>
            <p class="mt-2 text-slate-400">Revisa las fotografías reportadas y decide si se mantienen o se retiran.</p>
          </header>

          <div class="mb-6 flex gap-2">
            <button type="button" phx-click="change_tab" phx-value-tab="pending"
              class={["rounded-lg px-4 py-2 text-sm font-medium", @tab == "pending" && "bg-indigo-600 text-white" || "bg-slate-800 text-slate-300"]}>
              Pendientes ({Enum.count(@reports, &(&1.status == "Pendiente"))})
            </button>
            <button type="button" phx-click="change_tab" phx-value-tab="history"
              class={["rounded-lg px-4 py-2 text-sm font-medium", @tab == "history" && "bg-indigo-600 text-white" || "bg-slate-800 text-slate-300"]}>
              Historial ({Enum.count(@reports, &(&1.status == "Resuelto"))})
            </button>
          </div>

          <div class="grid gap-6 lg:grid-cols-3">
            <section class="lg:col-span-2 overflow-hidden rounded-xl border border-slate-800 bg-slate-900">
              <h2 class="border-b border-slate-800 px-5 py-4 font-semibold">
                {if @tab == "pending", do: "Reportes por revisar", else: "Reportes resueltos"}
              </h2>
              <div :if={@visible_reports == []} class="p-8 text-center text-slate-400">No hay reportes en esta sección.</div>
              <div class="divide-y divide-slate-800">
                <button :for={report <- @visible_reports} type="button"
                  phx-click="select_report" phx-value-id={report.id}
                  class="w-full p-5 text-left transition hover:bg-slate-800">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <div class="font-semibold">Foto #{report.photo_id} · {report.reason}</div>
                      <div class="mt-2 text-sm text-slate-400">Reportado por {report.reporter} · {report.date}</div>
                      <div class="mt-1 text-xs text-slate-500">Prioridad: {report.priority}</div>
                    </div>
                    <span class="rounded-full bg-slate-800 px-3 py-1 text-xs text-indigo-300">{report.resolution || report.status}</span>
                  </div>
                </button>
              </div>
            </section>

            <section class="rounded-xl border border-slate-800 bg-slate-900 p-5">
              <%= if @selected_report do %>
                <h2 class="text-lg font-semibold">Detalle del reporte #{ @selected_report.id }</h2>
                <div class="mt-4 flex min-h-40 items-center justify-center rounded-lg border border-dashed border-slate-700 bg-slate-800 text-center text-sm text-slate-400">
                  <%= if @selected_report.photo_url do %>
                    <img src={@selected_report.photo_url} alt={"Foto reportada ##{@selected_report.photo_id}"} class="max-h-72 w-full rounded-lg object-contain" />
                  <% else %>
                    Vista previa no disponible: falta conectar el almacenamiento de fotos.
                  <% end %>
                </div>
                <dl class="mt-5 space-y-3 text-sm">
                  <div><dt class="text-slate-400">Fotografía</dt><dd>#{@selected_report.photo_id}</dd></div>
                  <div><dt class="text-slate-400">Motivo</dt><dd>{@selected_report.reason}</dd></div>
                  <div><dt class="text-slate-400">Reportante</dt><dd>{@selected_report.reporter}</dd></div>
                  <div><dt class="text-slate-400">Estado</dt><dd>{@selected_report.resolution || @selected_report.status}</dd></div>
                </dl>
                <%= if @selected_report.status == "Pendiente" do %>
                  <div class="mt-6 space-y-3">
                    <button type="button" phx-click="resolve" phx-value-id={@selected_report.id} phx-value-action="approve"
                      data-confirm="¿Aprobar esta fotografía y cerrar el reporte?"
                      class="w-full rounded-lg bg-emerald-600 px-4 py-3 font-medium hover:bg-emerald-500">Aprobar fotografía</button>
                    <button type="button" phx-click="resolve" phx-value-id={@selected_report.id} phx-value-action="remove"
                      data-confirm="¿Marcar esta fotografía como retirada y cerrar el reporte?"
                      class="w-full rounded-lg bg-red-600 px-4 py-3 font-medium hover:bg-red-500">Retirar fotografía</button>
                  </div>
                <% end %>
              <% else %>
                <h2 class="font-semibold">Detalle del reporte</h2>
                <p class="mt-6 text-sm text-slate-400">Selecciona un reporte para revisar la fotografía y resolverlo.</p>
              <% end %>
            </section>
          </div>
          <p class="mt-6 text-xs text-amber-300">Versión demostrativa: las decisiones se guardan solo en memoria y no alteran fotografías reales. Se necesita integrar la API y la autenticación para completar RF-14.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
