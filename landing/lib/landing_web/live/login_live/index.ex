defmodule LandingWeb.LoginLive.Index do
  use LandingWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, message: nil, images: [
      "https://uvm.neocities.org/aves/fixtures/1-nothoprocta-perdicaria/image.jpg",
      "https://uvm.neocities.org/aves/fixtures/2-callipela-californica/image.jpg",
      "https://uvm.neocities.org/aves/fixtures/3-eudromia-elegans/image.jpg",
      "https://uvm.neocities.org/aves/fixtures/4-rollandia-rolland/image.jpg",
      "https://uvm.neocities.org/aves/fixtures/5-podiceps-occipitalis/image.jpg"
    ])

    {:ok, socket, layout: {LandingWeb.Layouts, :login_root}}
  end

  def render(assigns) do
    ~H"""
    <main class="relative flex min-h-screen items-center justify-center overflow-hidden bg-black px-4">

    <div class="background"></div> <!-- Fondo de gradiente radial -->

      <!-- BACKGROUND CASCADE LAYER -->
      <div class="absolute inset-0 z-0 opacity-60">
        <div class="stage" style="position: relative; width: 100%; height: 100vh; display: flex; align-items: center; justify-content: center;">
          <div id="hero-cascade" class="cascade-container">
            <div class="flex gap-8">
              <!-- Pista 1: Hacia arriba -->
              <div class="cascade-track" id="track-up">
                <%= for {image_url, index} <- Enum.with_index(@images) do %>
                  <div class="cascade-panel">
                    <div class="panel-image-wrapper">
                      <img src={image_url} alt={"Imagen #{index + 1}"} loading="lazy">
                      <div class="panel-scrim"></div>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Pista 2: Hacia abajo -->
              <div class="cascade-track" id="track-down">
                <%= for {image_url, index} <- Enum.reverse(Enum.with_index(@images)) do %>
                  <div class="cascade-panel">
                    <div class="panel-image-wrapper">
                      <img src={image_url} alt={"Imagen #{index + 1}"} loading="lazy">
                      <div class="panel-scrim"></div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Logo Layer -->
      <div class="absolute top-8 left-10 z-10 flex items-center gap-3">
        <a href={~p"/propaganda"} class="flex items-center gap-3">
          <img src={~p"/images/isotipo-main-logo.png"} alt="Logo" class="h-12 w-auto">
          <img src={~p"/images/coron-white.png"} alt="Logo Text" class="h-10 w-auto mt-1">
        </a>
      </div>

      <!-- LOGIN FORM LAYER -->
      <section class="relative z-10 w-full max-w-md rounded-xl bg-white/90 p-8 shadow-2xl backdrop-blur-sm">
        <div class="mb-6 text-center">
          <img src={~p"/images/coron-black.png"} alt="Logo-black" class="mx-auto h-25 w-auto">
          <h1 class="text-2xl font-bold text-gray-900">Iniciar Sesion</h1>
        </div>

        <form phx-submit="login" class="space-y-4">
          <div>
            <label for="email" class="mb-1 block text-sm font-medium text-gray-700">Correo Electrónico</label>
            <input
              id="email" name="email" type="email" autocomplete="email" required
              class="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-indigo-500 focus:outline-none"
            />
          </div>

          <div>
            <label for="password" class="mb-1 block text-sm font-medium text-gray-700">Contraseña</label>
            <input
              id="password" name="password" type="password" autocomplete="current-password" required
              class="w-full rounded-md border border-gray-300 px-3 py-2 focus:border-indigo-500 focus:outline-none"
            />
          </div>

          <button
            type="submit"
            class="w-full rounded-md bg-indigo-600 px-4 py-2 font-medium text-white hover:bg-indigo-700"
          >
            Iniciar Sesion
          </button>
        </form>

        <div class="my-4 flex items-center justify-center">
          <span class="text-sm text-gray-500">¿No tienes una cuenta?</span>
          <a href={~p"/signup/"} class="ml-2 text-sm font-medium text-indigo-600 hover:text-indigo-700">Registrate</a>
        </div>

        <p :if={@message} role="status" class="mt-4 text-center text-sm font-medium text-red-600">
          {@message}
        </p>
      </section>
    </main>
    """
  end

  def handle_event("login", %{"email" => email, "password" => password}, socket) do
    message =
      if String.trim(email) == "" or String.trim(password) == "" do
        "Ingresa tu Correo y Contraseña."
      else
        "Login no configurado aun."
      end

    {:noreply, assign(socket, message: message)}
  end
end
