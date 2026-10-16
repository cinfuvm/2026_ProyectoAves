defmodule LandingWeb.AdminLive.Aves.Index do
  use LandingWeb, :live_view
  alias Phoenix.LiveView.JS

  # -------------------------------------------------------------------
  # 1. INICIALIZACIÓN (Cuando la página carga por primera vez)
  # -------------------------------------------------------------------
  @impl true
  def mount(_params, _session, socket) do
    # Lista simulada inicial. (Más adelante, aquí consultarás tu base de datos Ecto)
    aves_mock = [
      %{id: 1, nombre_comun: "Zorzal", nombre_cientifico: "Turdus falcklandii", familia: "Turdidae"},
      %{id: 2, nombre_comun: "Loica", nombre_cientifico: "Leistes loyca", familia: "Icteridae"}
    ]

    # Inicializamos la lista de aves y dejamos :ave como nil (formulario vacío)
    {:ok, assign(socket, aves: aves_mock, ave: nil)}
  end

  # -------------------------------------------------------------------
  # 2. INTERFAZ GRÁFICA (HTML renderizado en la pantalla)
  # -------------------------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide={true}>
      <div class="min-h-screen bg-slate-950 text-white flex">

        <!-- BARRA LATERAL -->
        <aside class="hidden min-h-screen w-64 border-r border-slate-800 bg-slate-900 lg:block">
          <div class="p-6">
            <h1 class="text-xl font-bold">Proyecto Aves</h1>
            <p class="mt-1 text-sm text-slate-400">Administración</p>
          </div>
          <nav class="space-y-2 px-4">
            <.nav_item label="Dashboard" navigate={~p"/admin/"} />
            <.nav_item label="Aves" active navigate={~p"/admin/aves"} />
          </nav>
        </aside>

        <!-- CONTENIDO PRINCIPAL -->
        <main class="flex-1">
          <header class="border-b border-slate-800 bg-slate-900 px-6 py-4">
            <h2 class="text-2xl font-semibold">Gestión de Aves</h2>
            <p class="text-sm text-slate-400">Administración del catálogo de especies</p>
          </header>

          <section class="p-6">
            <div class="rounded-xl border border-slate-800 bg-slate-900">

              <!-- ENCABEZADO DE LA TABLA Y BOTÓN NUEVO -->
              <div class="flex items-center justify-between border-b border-slate-800 p-5">
                <div>
                  <h3 class="font-semibold">Catálogo de Especies</h3>
                </div>
                <!-- Botón Crear: Limpia el formulario (new) y abre el modal -->
                <button class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
                        phx-click={JS.push("new") |> show_modal("modal-nueva-ave")}>
                  Registrar Ave
                </button>
              </div>

              <!-- TABLA DE AVES -->
              <div class="w-full p-5 overflow-x-auto">
                <table class="w-full text-left text-sm">
                  <thead class="border-b border-slate-800 text-slate-400">
                    <tr>
                      <th class="px-5 py-4">Nombre Común</th>
                      <th class="px-5 py-4">Nombre Científico</th>
                      <th class="px-5 py-4">Familia</th>
                      <th class="px-5 py-4 text-right">Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    <!-- Bucle para dibujar cada ave en la tabla -->
                    <%= for ave <- @aves do %>
                      <tr class="border-b border-slate-800/70 hover:bg-slate-800/40" id={"ave-#{ave.id}"}>
                        <td class="px-5 py-4 font-medium"><%= ave.nombre_comun %></td>
                        <td class="px-5 py-4 text-slate-400 italic"><%= ave.nombre_cientifico %></td>
                        <td class="px-5 py-4"><%= ave.familia %></td>
                        <td class="px-5 py-4 text-right space-x-2">
                          <!-- Botón Editar: Carga los datos (edit) y abre el modal -->
                          <button class="rounded-lg bg-slate-600 px-3 py-1 text-sm font-medium text-white hover:bg-slate-400"
                                  phx-click={JS.push("edit", value: %{id: ave.id}) |> show_modal("modal-nueva-ave")}>
                            Editar
                          </button>
                          <button class="rounded-lg bg-red-600 px-3 py-1 text-sm font-medium text-white hover:bg-red-500"
                                  phx-click={JS.push("seleccionar_ave", value: %{id: ave.id}) |> show_modal("modal-confirmar-eliminar")}>
                            Eliminar
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- MODAL DE ELIMINAR -->
              <.modal id="modal-confirmar-eliminar">
                <div class="modal-content p-6 text-center">
                  <h1 class="font-bold mb-4">Confirmar Eliminación</h1>
                  <p class="text-slate-950">¿Estás seguro de que deseas eliminar esta ave?</p>
                  <p class="mb-5 text-tiny text-red-600">Esta acción no se puede deshacer.</p>
                  <div class="flex justify-center gap-4">
                    <button type="button" phx-click={JS.exec("data-cancel", to: "#modal-confirmar-eliminar")} class="bg-gray-300 px-4 py-2 rounded hover:bg-gray-400">Cancelar</button>
                    <button type="button" phx-click={JS.push("delete", value: %{id: @ave && @ave.id}) |> JS.exec("data-cancel", to: "#modal-confirmar-eliminar")} class="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-500">Eliminar</button>
                  </div>
                </div>
              </.modal>

              <!-- MODAL DEL FORMULARIO -->
              <.modal id="modal-nueva-ave">
                <form class="modal-content" phx-submit={JS.push("save") |> JS.exec("data-cancel", to: "#modal-nueva-ave")} id="ave-form">
                  <div class="container p-2 text-slate-800">
                    <h1 class="text-2xl font-bold mb-2">Registrar / Editar Ave</h1>
                    <hr class="mb-4 border-gray-300">

                    <!-- ID Oculto (Vital para saber si estamos editando) -->
                    <input type="hidden" id="ave-id-oculto" name="ave[id]" value={if @ave, do: @ave.id, else: ""} />

                    <!-- Campos de texto (Se llenan automáticamente si @ave existe) -->
                    <label class="block font-bold">Nombre Común</label>
                    <input type="text" id="input-nombre-comun" name="ave[nombre_comun]" value={if @ave, do: @ave.nombre_comun, else: ""} required class="w-full mb-4 border p-2 rounded text-black">

                    <label class="block font-bold">Nombre Científico</label>
                    <input type="text" id="input-nombre-cientifico" name="ave[nombre_cientifico]" value={if @ave, do: @ave.nombre_cientifico, else: ""} required class="w-full mb-4 border p-2 rounded text-black">

                    <label class="block font-bold">Familia</label>
                    <input type="text" id="input-familia" name="ave[familia]" value={if @ave, do: @ave.familia, else: ""} required class="w-full mb-4 border p-2 rounded text-black">

                    <div class="flex gap-4">
                      <button type="button" phx-click={JS.exec("data-cancel", to: "#modal-nueva-ave")} class="bg-gray-300 px-4 py-2 rounded hover:bg-gray-400">Cancelar</button>
                      <button type="submit" class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-500">Guardar Ave</button>
                    </div>
                  </div>
                </form>
              </.modal>

            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # -------------------------------------------------------------------
  # 3. MANEJO DE EVENTOS (Cuando el usuario hace clic en botones)
  # -------------------------------------------------------------------

  # Prepara el modal para crear un ave nueva (borra datos antiguos)
  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, :ave, nil)}
  end

  # Prepara el modal para editar, buscando el ave en la lista actual
  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    ave_a_editar = Enum.find(socket.assigns.aves, fn a -> to_string(a.id) == to_string(id) end)
    {:noreply, assign(socket, :ave, ave_a_editar)}
  end

  # Borra un ave de la lista
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    lista_actualizada = Enum.reject(socket.assigns.aves, fn a -> to_string(a.id) == to_string(id) end)
    {:noreply, assign(socket, aves: lista_actualizada)}
  end

  @impl true
  def handle_event("seleccionar_ave", %{"id" => id}, socket) do
    # Encuentra el ave y la asigna al socket, pero NO la borra
    ave_seleccionada = Enum.find(socket.assigns.aves, fn a -> to_string(a.id) == to_string(id) end)

    {:noreply, assign(socket, :ave, ave_seleccionada)}
  end

  # Guarda los datos del formulario (Sirve para Crear Y Editar)
  @impl true
  def handle_event("save", %{"ave" => ave_params}, socket) do
    id = ave_params["id"]

    if id && id != "" do
      # --- FLUJO: ACTUALIZAR AVE EXISTENTE ---
      id_int = String.to_integer(id)

      lista_actualizada = Enum.map(socket.assigns.aves, fn a ->
        if a.id == id_int do
          %{a | nombre_comun: ave_params["nombre_comun"],
                nombre_cientifico: ave_params["nombre_cientifico"],
                familia: ave_params["familia"]}
        else
          a
        end
      end)

      {:noreply,
        socket
        |> assign(aves: lista_actualizada, ave: nil)
        |> put_flash(:info, "Ave guardada correctamente")}

    else
      # --- FLUJO: CREAR AVE NUEVA ---
      nueva_ave = %{
        id: System.unique_integer([:positive]),
        nombre_comun: ave_params["nombre_comun"],
        nombre_cientifico: ave_params["nombre_cientifico"],
        familia: ave_params["familia"]
      }

      lista_actualizada = socket.assigns.aves ++ [nueva_ave]

      {:noreply,
       socket
       |> assign(aves: lista_actualizada, ave: nil)
       |> put_flash(:info, "Ave registrada correctamente")
       |> push_event("js-exec", %{to: "#modal-nueva-ave", attr: "data-cancel"})}
    end
  end

end
