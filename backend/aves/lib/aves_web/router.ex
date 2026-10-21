defmodule AvesWeb.Router do
  use AvesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AvesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug AvesWeb.AuthPlug
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/json/open_api",
      default_model_expand_depth: 4

    forward "/", AvesWeb.AshJsonApiRouter
  end

  scope "/api", AvesWeb.API do
    pipe_through [:api]

    post "/user/signin", UserController, :register
    post "/user/login", UserController, :login
    delete "/user/logout", UserController, :logout
  end

  scope "/api", AvesWeb.API do
    pipe_through [:api_auth]

    get "/user/me", UserController, :me
    patch "/user/me", UserController, :update_me

    # RF-05 and RF-06
    get "/birds/ranking", BirdController, :ranking # Ranking de aves más vistas

    get "/birds", BirdController, :index
    get "/birds/:id", BirdController, :show
    post "/birds", BirdController, :create
    patch "/birds/:id", BirdController, :update
    delete "/birds/:id", BirdController, :delete

    get "/categories", CategoryController, :index
    post "/categories", CategoryController, :create
    patch "/categories/:id", CategoryController, :update
    delete "/categories/:id", CategoryController, :delete

    # RF-08 / RF-09 / RF-10 - Personal sightings (bitacora)
    post "/sightings", SightingController, :create
    get "/sightings", SightingController, :index
    patch "/sightings/:id", SightingController, :update
    delete "/sightings/:id", SightingController, :delete

    # RF-11 - Photos from other users (filterable)
    get "/photos", PhotoController, :index

    # RF-12 - Personal collection
    get "/collection", CollectionController, :index
    post "/collection", CollectionController, :create
    delete "/collection/:id", CollectionController, :delete

    # RF-13 / RF-14 - Reports and moderator queue
    post "/reports", ReportController, :create
    get "/reports", ReportController, :index
    post "/reports/:id/approve", ReportController, :approve
    post "/reports/:id/retire", ReportController, :retire
  end

  scope "/", AvesWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", AvesWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:aves, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AvesWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
