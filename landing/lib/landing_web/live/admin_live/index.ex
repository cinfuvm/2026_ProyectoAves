defmodule LandingWeb.AdminLive.Index do
  use LandingWeb, :live_view
  alias Phoenix.LiveView.JS

  # -------------------------------------------------------------------
  # 1. INICIALIZACIÓN
  # -------------------------------------------------------------------
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Panel Administrador",
       stats: %{users: 1248, moderators: 8, reports: 34, active_users: 921},
       users: [
         %{id: 1, name: "Ana Pérez", email: "ana@email.com", password: "hash_secreto", role: "Usuario", status: "Activo"},
         %{id: 2, name: "Carlos Soto", email: "carlos@email.com", password: "hash_secreto", role: "Moderador", status: "Activo"},
         %{id: 3, name: "María Díaz", email: "maria@email.com", password: "hash_secreto", role: "Usuario", status: "Suspendido"}
       ],
       user: nil
     )}
  end

  # -------------------------------------------------------------------
  # 2. INTERFAZ GRÁFICA
  # -------------------------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide={true}>
      <div class="min-h-screen bg-slate-950 text-white flex">

        <aside class="hidden min-h-screen w-64 border-r border-slate-800 bg-slate-900 lg:block">
          <div class="p-6">
            <h1 class="text-xl font-bold">Proyecto Aves</h1>
            <p class="mt-1 text-sm text-slate-400">Administración</p>
          </div>
          <nav class="space-y-2 px-4">
            <.nav_item label="Dashboard" active navigate={~p"/admin/"} />
            <.nav_item label="Aves" navigate={~p"/admin/aves"} />
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
                <p class="text-sm text-slate-400">Control general de la plataforma</p>
              </div>
              <div class="flex items-center gap-3">
                <div class="text-right">
                  <p class="text-sm font-medium">Administrador</p>
                  <p class="text-xs text-slate-400">admin@aves.cl</p>
                </div>
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-600 font-bold">A</div>
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
                    <p class="text-sm text-slate-400">Gestión de cuentas y permisos</p>
                  </div>
                  <button class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
                          phx-click={JS.push("new") |> show_modal("modal-usuario-nuevo")}>
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
                        <th class="px-5 py-4 text-right">Acciones</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for user <- @users do %>
                        <tr class="border-b border-slate-800/70 hover:bg-slate-800/40" id={"user-#{user.id}"}>
                          <td class="px-5 py-4 font-medium"><%= user.name %></td>
                          <td class="px-5 py-4 text-slate-400"><%= user.email %></td>
                          <td class="px-5 py-4"><%= user.role %></td>
                          <td class="px-5 py-4">
                            <span class={[
                              "rounded-full px-2 py-1 text-xs",
                              user.status == "Activo" && "bg-emerald-500/10 text-emerald-400",
                              user.status != "Activo" && "bg-red-500/10 text-red-400"
                            ]}>
                              <%= user.status %>
                            </span>
                          </td>
                          <td class="px-5 py-4 text-right space-x-2">
                            <button class="rounded-lg bg-slate-600 px-3 py-1 text-sm font-medium text-white hover:bg-slate-400"
                                    phx-click={JS.push("edit", value: %{id: user.id}) |> show_modal("modal-usuario-nuevo")}>
                              Editar
                            </button>
                            <button class="rounded-lg bg-red-600 px-3 py-1 text-sm font-medium text-white hover:bg-red-500"
                                    phx-click={JS.push("seleccionar_usuario", value: %{id: user.id}) |> show_modal("modal-confirmar-eliminar")}>
                              Eliminar
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
                <p class="mt-1 text-sm text-slate-400">Resumen de acciones recientes</p>
                <div class="mt-6 space-y-5">
                  <.activity title="Nuevo moderador agregado" text="Carlos Soto fue asignado como moderador." />
                  <.activity title="Usuario suspendido" text="Se suspendió una cuenta tras múltiples reportes." />
                  <.activity title="Reportes revisados" text="12 reportes fueron cerrados hoy." />
                </div>
              </div>
            </div>

            <!-- MODAL: CREAR/EDITAR USUARIO -->
            <.modal id="modal-usuario-nuevo">
              <form class="modal-content" phx-submit={JS.push("save") |> JS.exec("data-cancel", to: "#modal-usuario-nuevo")} id="user-form-element">
                <div class="container p-2 text-slate-800">
                  <h1 class="text-2xl font-bold mb-2"><%= if @user, do: "Editar Usuario", else: "Crear Usuario" %></h1>
                  <hr class="mb-4 border-gray-300">

                  <input type="hidden" id="hidden-user-id" name="usuario[id]" value={if @user, do: @user.id, else: ""} />

                  <label for="name" class="block font-bold">Nombre</label>
                  <input type="text" id="input-user-name" name="usuario[name]" placeholder="Nombre" value={if @user, do: @user.name, else: ""} required class="w-full mb-4 border p-2 rounded text-black">
                  <p class="text-xs text-gray-500 -mt-3 mb-4"><%= if @user, do: "Déjalo en blanco para mantener la actual", else: "" %></p>

                  <label for="email" class="block font-bold">Correo Electrónico</label>
                  <input type="email" id="input-user-email" name="usuario[email]" placeholder="Correo Electrónico" value={if @user, do: @user.email, else: ""} required class="w-full mb-4 border p-2 rounded text-black">

                  <!-- NUEVO CAMPO DE CONTRASEÑA -->
                  <label for="password" class="block font-bold">Contraseña</label>
                  <input type="password" id="input-user-password" name="usuario[password]" placeholder="Contraseña" required={is_nil(@user)} class="w-full mb-4 border p-2 rounded text-black">
                  <p class="text-xs text-gray-500 -mt-3 mb-4"><%= if @user, do: "Déjalo en blanco para mantener la actual", else: "" %></p>

                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <label class="block font-bold">Rol</label>
                      <select id="input-user-role" name="usuario[role]" class="w-full mb-4 border p-2 rounded text-black">
                        <option value="Usuario" selected={@user && @user.role == "Usuario"}>Usuario</option>
                        <option value="Moderador" selected={@user && @user.role == "Moderador"}>Moderador</option>
                        <option value="Administrador" selected={@user && @user.role == "Administrador"}>Administrador</option>
                      </select>
                    </div>
                    <div>
                      <label class="block font-bold">Estado</label>
                      <select id="input-user-status" name="usuario[status]" class="w-full mb-4 border p-2 rounded text-black">
                        <option value="Activo" selected={@user && @user.status == "Activo"}>Activo</option>
                        <option value="Suspendido" selected={@user && @user.status == "Suspendido"}>Suspendido</option>
                      </select>
                    </div>
                  </div>

                  <div class="flex gap-4 mt-2">
                    <button type="button" phx-click={JS.exec("data-cancel", to: "#modal-usuario-nuevo")} class="bg-gray-300 px-4 py-2 rounded hover:bg-gray-400">Cancelar</button>
                    <button type="submit" class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-500">Guardar Usuario</button>
                  </div>
                </div>
              </form>
            </.modal>

            <!-- MODAL: CONFIRMAR ELIMINACIÓN -->
            <.modal id="modal-confirmar-eliminar">
              <div class="modal-content p-6 text-center text-slate-800">
                <h2 class="text-xl font-bold mb-4">Confirmar Eliminación</h2>
                <p>¿Estás seguro de que deseas eliminar al usuario <b><%= @user && @user.name %></b>?</p>
                <p class="mb-6 mt-2 text-sm text-red-600 block">Esta acción no se puede deshacer.</p>

                <div class="flex justify-center gap-4">
                  <button type="button" phx-click={JS.exec("data-cancel", to: "#modal-confirmar-eliminar")} class="bg-gray-300 px-4 py-2 rounded hover:bg-gray-400">Cancelar</button>
                  <button type="button" phx-click={JS.push("delete", value: %{id: @user && @user.id}) |> JS.exec("data-cancel", to: "#modal-confirmar-eliminar")} class="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-500">Eliminar</button>
                </div>
              </div>
            </.modal>

          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # -------------------------------------------------------------------
  # 3. COMPONENTES LOCALES
  # -------------------------------------------------------------------
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

  # -------------------------------------------------------------------
  # 4. MANEJO DE EVENTOS
  # -------------------------------------------------------------------
  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, :user, nil)}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    user_a_editar = Enum.find(socket.assigns.users, fn u -> to_string(u.id) == to_string(id) end)
    {:noreply, assign(socket, :user, user_a_editar)}
  end

  @impl true
  def handle_event("seleccionar_usuario", %{"id" => id}, socket) do
    user_seleccionado = Enum.find(socket.assigns.users, fn u -> to_string(u.id) == to_string(id) end)
    {:noreply, assign(socket, :user, user_seleccionado)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    lista_actualizada = Enum.reject(socket.assigns.users, fn u -> to_string(u.id) == to_string(id) end)
    nuevas_stats = %{socket.assigns.stats | users: socket.assigns.stats.users - 1}
    {:noreply, assign(socket, users: lista_actualizada, stats: nuevas_stats, user: nil)}
  end

  @impl true
  def handle_event("save", %{"usuario" => params}, socket) do
    id = params["id"]

    if id && id != "" do
      # ACTUALIZAR USUARIO
      id_int = String.to_integer(id)

      lista_actualizada = Enum.map(socket.assigns.users, fn u ->
        if u.id == id_int do
          # Si la contraseña viene en blanco, mantenemos la anterior
          pass = if params["password"] == "", do: u.password, else: params["password"]

          %{u | name: params["name"], email: params["email"], password: pass, role: params["role"], status: params["status"]}
        else
          u
        end
      end)

      {:noreply,
       socket
       |> assign(users: lista_actualizada, user: nil)
       |> put_flash(:info, "Usuario actualizado correctamente")}
    else
      # CREAR USUARIO
      nuevo_usuario = %{
        id: System.unique_integer([:positive]),
        name: params["name"],
        email: params["email"],
        password: params["password"],
        role: params["role"],
        status: params["status"]
      }

      lista_actualizada = [nuevo_usuario | socket.assigns.users]
      nuevas_stats = %{socket.assigns.stats | users: socket.assigns.stats.users + 1}

      {:noreply,
       socket
       |> assign(users: lista_actualizada, stats: nuevas_stats, user: nil)
       |> put_flash(:info, "Usuario creado exitosamente")}
    end
  end
end
