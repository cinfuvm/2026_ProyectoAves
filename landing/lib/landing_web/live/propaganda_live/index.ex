defmodule LandingWeb.PropagandaLive.Index do
  use LandingWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, :images, [
       "https://uvm.neocities.org/aves/fixtures/1-nothoprocta-perdicaria/image.jpg",
       "https://uvm.neocities.org/aves/fixtures/2-callipela-californica/image.jpg",
       "https://uvm.neocities.org/aves/fixtures/3-eudromia-elegans/image.jpg",
       "https://uvm.neocities.org/aves/fixtures/4-rollandia-rolland/image.jpg",
       "https://uvm.neocities.org/aves/fixtures/5-podiceps-occipitalis/image.jpg"
     ]),
     layout: {LandingWeb.Layouts, :propaganda_root}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <head>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/priv/static/assets/css/propaganda.css">
    </head>

    <body class="visuals-on">

    <div class="stars"></div>
    <div class="aura"></div>

    <nav class="nav">
      <!-- Logo -->
      <a href="/propaganda" class="logo flex items-center gap-3">
        <img src={~p"/images/isotipo-main-logo.png"} alt="Logo" class="h-12 w-auto">
        <img src={~p"/images/coron-white.png"} alt="Logo Text" class="h-10 w-auto mt-1">
      </a>

      <ul class="nav-links">
        <li><a href="login">Iniciar Sesion</a></li>
      </ul>
      <button class="menu-toggle" aria-label="Open menu" aria-expanded="false">
        <span></span><span></span><span></span>
      </button>
    </nav>

    <div class="mobile-menu">
      <a href="#capabilities">Capabilities</a>
      <a href="login">Iniciar Sesion</a>
    </div>

    <header class="hero">
      <div class="stage">
        <div class="parallax">
          <div class="ring-tilt">
            <div class="ring" id="ring">
              <!-- El bucle recorre tu lista @images automáticamente -->
              <%= for {image_url, index} <- Enum.with_index(@images) do %>
                <div class="panel">
                  <div class="panel-face panel-face--text">
                    <div class="p-num">0<%= index + 1 %></div>
                    <div>
                      <div class="p-label">PANEL <%= index + 1 %></div>
                      <div class="p-meta">AXIS-X</div>
                    </div>
                  </div>
                  <div class="panel-face panel-face--image">
                    <!-- Aquí inyectamos la URL de la imagen en el atributo src -->
                    <img src={image_url} alt={"Imagen #{index + 1}"} loading="lazy">
                    <div class="panel-scrim"></div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
            <div class="hero-text">
              <div class="flex items-center justify-center gap-3 mb-4">
                <img src={~p"/images/coron-black.png"} alt="Logo Text" class="h-15 w-auto mt-1">
              </div>
              <h1>ENSEÑANOS TU VISION</h1>
              <p>Una red social diseñada para compartir tu visión del mundo y tu amor por las aves en Chile.</p>
            </div>
        </div>
      </div>
      <div class="scroll-cue">
        <span>DESCUBRE MAS</span>
        <div class="line"></div>
      </div>
    </header>

    <section class="section" id="system">
      <div class="section-head reveal">
        <div class="eyebrow">// EL SISTEMA</div>
        <h2>Explora. Documenta. Conserva.</h2>
        <p>CORON es una plataforma interactiva diseñada para amantes de la ornitología y la fotografía. Sube tus mejores capturas, explora avistamientos de otros usuarios y construye un registro visual de la biodiversidad de nuestro país.</p>
      </div>
      <div class="features" id="capabilities">
        <div class="feature reveal">
          <div class="f-index">01 // GALERÍA</div>
          <h3>Exhibición Inmersiva</h3>
          <p>Tus fotografías se presentan en una interfaz fluida y moderna. Destaca los detalles de cada plumaje y comparte los datos técnicos de tus capturas fotográficas en alta resolución.</p>
        </div>
        <div class="feature reveal">
          <div class="f-index">02 // COMUNIDAD</div>
          <h3>Conecta con Expertos</h3>
          <p>Interactúa con otros observadores de aves. Comenta en sus avistamientos, comparte ubicaciones y ayuda a identificar aquellas especies raras o difíciles de catalogar en diferentes regiones.</p>
        </div>
        <div class="feature reveal">
          <div class="f-index">03 // REGISTRO</div>
          <h3>Tu Bitácora Personal</h3>
          <p>Mantén un registro organizado de todas las especies que has logrado fotografiar. Añade datos de geolocalización, fecha, comportamiento y notas sobre el hábitat de cada ave.</p>
        </div>
      </div>
    </section>

    <section class="cta" id="launch">
      <div class="reveal">
        <h2>¿Listo para emprender el vuelo?</h2>
        <p>Únete a nuestra comunidad hoy mismo y empieza a compartir tu pasión por la vida silvestre con miles de observadores y fotógrafos.</p>
        <a href="signup" class="btn">CREAR MI CUENTA</a>
      </div>
    </section>

    <footer class="footer">
      <div class="logo">
        <a href="#" class="logo">
          <img src={~p"/images/coron-white.png"} alt="Logo Text" class="h-10 w-auto mt-1">
        </a>
      </div>
    </footer>

    <script src="/priv/static/assets/js/propaganda.js"></script>

    </body>
    """
  end
end
