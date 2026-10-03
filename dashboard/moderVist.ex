defmodule ProyectoAvesWeb.ModeratorLive.Index do
  use ProyectoAvesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    reports = [
      %{
        id: 1,
        type: "Contenido inapropiado",
        reporter: "Juan Pérez",
        target: "Publicación #132",
        status: "Pendiente",
        priority: "Alta"
      },
      %{
        id: 2,
        type: "Spam",
        reporter: "Daniela Ruiz",
        target: "Usuario #82",
        status: "Pendiente",
        priority: "Media"
      },
      %{
        id: 3,
        type: "Información falsa",
        reporter: "Pedro Silva",
        target: "Publicación #221",
        status: "En revisión",
        priority: "Baja"
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Moderación",
       reports: reports,
       selected_report: nil
     )}
  end

  @impl true
  def handle_event("select_report", %{"id" => id}, socket) do
    id = String.to_integer(id)

    report =
      Enum.find(socket.assigns.reports, fn report ->
        report.id == id
      end)

    {:noreply, assign(socket, selected_report: report)}
  end

  @impl true
  def handle_event("resolve", %{"id" => id}, socket) do
    id = String.to_integer(id)

    reports =
      Enum.map(socket.assigns.reports, fn report ->
        if report.id == id do
          %{report | status: "Resuelto"}
        else
          report
        end
      end)

    {:noreply,
     socket
     |> assign(:reports, reports)
     |> assign(:selected_report, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-white">
      <div class="flex">
        <aside class="hidden min-h-screen w-64 border-r border-slate-800 bg-slate-900 lg:block">
          <div class="p-6">
            <h1 class="text-xl font-bold">Proyecto Aves</h1>
            <p class="text-sm text-slate-400">Moderación</p>
          </div>

          <nav class="space-y-2 px-4">
            <a class="block rounded-lg bg-indigo-600 px-4 py-3 text-sm font-medium">
              Reportes
            </a>

            <a class="block rounded-lg px-4 py-3 text-sm text-slate-400 hover:bg-slate-800">
              Historial
            </a>

            <a class="block rounded-lg px-4 py-3 text-sm text-slate-400 hover:bg-slate-800">
              Usuarios
            </a>
          </nav>
        </aside>

        <main class="flex-1">
          <header class="border-b border-slate-800 bg-slate-900 px-6 py-4">
            <h2 class="text-2xl font-semibold">Centro de Moderación</h2>
            <p class="text-sm text-slate-400">
              Revisión de reportes y contenido
            </p>
          </header>

          <section class="p-6">
            <div class="grid gap-6 lg:grid-cols-3">
              <div class="lg:col-span-2">
                <div class="rounded-xl border border-slate-800 bg-slate-900">
                  <div class="border-b border-slate-800 p-5">
                    <h3 class="font-semibold">Reportes pendientes</h3>
                  </div>

                  <div class="divide-y divide-slate-800">
                    <%= for report <- @reports do %>
                      <button
                        phx-click="select_report"
                        phx-value-id={report.id}
                        class="w-full p-5 text-left transition hover:bg-slate-800/50"
                      >
                        <div class="flex items-start justify-between gap-4">
                          <div>
                            <div class="flex items-center gap-3">
                              <p class="font-medium"><%= report.type %></p>

                              <span class={[
                                "rounded-full px-2 py-1 text-xs",
                                report.priority == "Alta" &&
                                  "bg-red-500/10 text-red-400",
                                report.priority == "Media" &&
                                  "bg-yellow-500/10 text-yellow-400",
                                report.priority == "Baja" &&
                                  "bg-slate-700 text-slate-300"
                              ]}>
                                <%= report.priority %>
                              </span>
                            </div>

                            <p class="mt-2 text-sm text-slate-400">
                              Reportado por <%= report.reporter %>
                            </p>

                            <p class="text-sm text-slate-500">
                              <%= report.target %>
                            </p>
                          </div>

                          <span class="text-sm text-indigo-400">
                            <%= report.status %>
                          </span>
                        </div>
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>

              <div>
                <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
                  <%= if @selected_report do %>
                    <h3 class="font-semibold">Detalle del reporte</h3>

                    <div class="mt-5 space-y-4 text-sm">
                      <div>
                        <p class="text-slate-500">Tipo</p>
                        <p><%= @selected_report.type %></p>
                      </div>

                      <div>
                        <p class="text-slate-500">Reportado por</p>
                        <p><%= @selected_report.reporter %></p>
                      </div>

                      <div>
                        <p class="text-slate-500">Elemento</p>
                        <p><%= @selected_report.target %></p>
                      </div>

                      <div>
                        <p class="text-slate-500">Estado</p>
                        <p><%= @selected_report.status %></p>
                      </div>
                    </div>

                    <div class="mt-6 space-y-3">
                      <button
                        phx-click="resolve"
                        phx-value-id={@selected_report.id}
                        class="w-full rounded-lg bg-emerald-600 px-4 py-2 font-medium hover:bg-emerald-500"
                      >
                        Aprobar / Resolver
                      </button>

                      <button class="w-full rounded-lg bg-red-600 px-4 py-2 font-medium hover:bg-red-500">
                        Eliminar contenido
                      </button>

                      <button class="w-full rounded-lg border border-slate-700 px-4 py-2 font-medium hover:bg-slate-800">
                        Suspender usuario
                      </button>
                    </div>
                  <% else %>
                    <div class="py-10 text-center text-slate-500">
                      Selecciona un reporte para ver sus detalles.
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
    """
  end
end