defmodule AvesWeb.Router do
  use AvesWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AvesWeb do
    pipe_through :api

    # 1 RUTAS PÚBLICAS
    get "/birds", BirdController, :index
    get "/birds/:id", BirdController, :show

    get "/posts", PostController, :index
    get "/posts/:id", PostController, :show


    # 2 RUTAS DE USUARIO REGISTRADO
    post "/posts", PostController, :create
    put "/posts/:id", PostController, :update       # (Solo el dueño de la cuenta)
    delete "/posts/:id", PostController, :delete    # (Solo el Moderador o Admin)

    # Interacciones (Dar/Quitar me gusta)
    post "/posts/:id_publicacion/likes", LikeController, :create
    delete "/posts/:id_publicacion/likes", LikeController, :delete

    # Denuncias de Contenido
    post "/reports", ReportController, :create      # Cualquier usuario puede denunciar

    # 3 RUTAS DE MODERACIÓN
    get "/reports", ReportController, :index
    get "/reports/:id", ReportController, :show
    delete "/reports/:id", ReportController, :delete

    # 4 RUTAS DE ADMINISTRACIÓN EXCLUSIVA
    post "/birds", BirdController, :create
    put "/birds/:id", BirdController, :update
    delete "/birds/:id", BirdController, :delete
    get "/birds/ranking", BirdController, :rankingS

    get "/users", UserController, :index
    get "/users/:id", UserController, :show
    patch "/users/:id/role", UserController, :update_role # Cambiar rol a moderador/admin
    delete "/users/:id", UserController, :delete

  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:aves, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: AvesWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
