defmodule ProyectoAvesWeb.AdminLive.Index do
  use ProyectoAvesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Panel Administrador",
       stats: %{
         users: 1248,
         moderators: 8,
         reports: 34,
         active_users: 921
       },
       users: [
         %{id: 1, name: "Ana Pérez", email: "ana@email.com", role: "Usuario", status: "Activo"},
         %{id: 2, name: "Carlos Soto", email: "carlos@email.com", role: "Moderador", status: "Activo"},
         %{id: 3, name: "María Díaz", email: "maria@email.com", role: "Usuario", status: "Suspendido"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-white">
      <div class="flex">

        <aside class="hidden min-h-screen w-64 border-r border-slate-800 bg-slate-900 lg:block">
          <div class="p-6">
            <h1 class="text-xl font-bold">Proyecto Aves</h1>
            <p class="mt-1 text-sm text-slate-400">Administración</p>
          </div>

          <nav class="space-y-2 px-4">
            <.nav_item label="Dashboard" active />
            <.nav_item label="Usuarios" />
            <.nav_item label="Moderadores" />
            <.nav_item label="Reportes" />
            <.nav_item label="Configuración" />
          </nav>
        </aside>

        <main class="flex-1">
          <header class="border-b border-slate-800 bg-slate-900 px-6 py-4">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-2xl font-semibold">Panel de Administración</h2>
                <p class="text-sm text-slate-400">
                  Control general de la plataforma
                </p>
              </div>

              <div class="flex items-center gap-3">
                <div class="text-right">
                  <p class="text-sm font-medium">Administrador</p>
                  <p class="text-xs text-slate-400">admin@aves.cl</p>
                </div>

                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-600 font-bold">
                  A
                </div>
              </div>
            </div>
          </header>

          <section class="p-6">
            <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <.stat_card title="Usuarios" value={@stats.users} />
              <.stat_card title="Usuarios activos" value={@stats.active_users} />
              <.stat_card title="Moderadores" value={@stats.moderators} />
              <.stat_card title="Reportes pendientes" value={@stats.reports} />
            </div>

            <div class="mt-8 grid gap-6 xl:grid-cols-3">
              <div class="rounded-xl border border-slate-800 bg-slate-900 xl:col-span-2">
                <div class="flex items-center justify-between border-b border-slate-800 p-5">
                  <div>
                    <h3 class="font-semibold">Usuarios recientes</h3>
                    <p class="text-sm text-slate-400">
                      Gestión de cuentas y permisos
                    </p>
                  </div>

                  <button class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium hover:bg-indigo-500">
                    Nuevo usuario
                  </button>
                </div>

                <div class="overflow-x-auto">
                  <table class="w-full text-left text-sm">
                    <thead class="border-b border-slate-800 text-slate-400">
                      <tr>
                        <th class="px-5 py-4">Nombre</th>
                        <th class="px-5 py-4">Correo</th>
                        <th class="px-5 py-4">Rol</th>
                        <th class="px-5 py-4">Estado</th>
                        <th class="px-5 py-4"></th>
                      </tr>
                    </thead>

                    <tbody>
                      <%= for user <- @users do %>
                        <tr class="border-b border-slate-800/70 hover:bg-slate-800/40">
                          <td class="px-5 py-4 font-medium"><%= user.name %></td>
                          <td class="px-5 py-4 text-slate-400"><%= user.email %></td>
                          <td class="px-5 py-4"><%= user.role %></td>
                          <td class="px-5 py-4">
                            <span class={[
                              "rounded-full px-2 py-1 text-xs",
                              user.status == "Activo" &&
                                "bg-emerald-500/10 text-emerald-400",
                              user.status != "Activo" &&
                                "bg-red-500/10 text-red-400"
                            ]}>
                              <%= user.status %>
                            </span>
                          </td>
                          <td class="px-5 py-4 text-right">
                            <button class="text-indigo-400 hover:text-indigo-300">
                              Gestionar
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>

              <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
                <h3 class="font-semibold">Actividad del sistema</h3>
                <p class="mt-1 text-sm text-slate-400">
                  Resumen de acciones recientes
                </p>

                <div class="mt-6 space-y-5">
                  <.activity
                    title="Nuevo moderador agregado"
                    text="Carlos Soto fue asignado como moderador."
                  />
                  <.activity
                    title="Usuario suspendido"
                    text="Se suspendió una cuenta tras múltiples reportes."
                  />
                  <.activity
                    title="Reportes revisados"
                    text="12 reportes fueron cerrados hoy."
                  />
                </div>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
      <p class="text-sm text-slate-400"><%= @title %></p>
      <p class="mt-2 text-3xl font-bold"><%= @value %></p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <a
      href="#"
      class={[
        "block rounded-lg px-4 py-3 text-sm font-medium transition",
        @active && "bg-indigo-600 text-white",
        !@active && "text-slate-400 hover:bg-slate-800 hover:text-white"
      ]}
    >
      <%= @label %>
    </a>
    """
  end

  attr :title, :string, required: true
  attr :text, :string, required: true

  defp activity(assigns) do
    ~H"""
    <div class="border-l-2 border-indigo-500 pl-4">
      <p class="font-medium"><%= @title %></p>
      <p class="mt-1 text-sm text-slate-400"><%= @text %></p>
    </div>
    """
  end
end