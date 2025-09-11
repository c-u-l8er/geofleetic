defmodule GeoFleeticWeb.Router do
  use GeoFleeticWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GeoFleeticWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :authenticated do
    plug GeoFleeticWeb.Plugs.Auth
  end

  pipeline :no_csrf do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GeoFleeticWeb.Layouts, :root}
    plug :put_secure_browser_headers
  end

  pipeline :tenant do
    plug GeoFleeticWeb.Plugs.Tenant
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GeoFleeticWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/auth", GeoFleeticWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    get "/callback", AuthController, :callback
    post "/callback", AuthController, :callback
    post "/tenant/:tenant_id", AuthController, :select_tenant
    get "/logout", AuthController, :logout
  end

  scope "/tenant", GeoFleeticWeb do
    pipe_through [:browser, :authenticated]

    get "/select", TenantController, :select
  end

  scope "/organizations", GeoFleeticWeb do
    pipe_through [:no_csrf, :authenticated]

    get "/manage", OrganizationController, :manage
    post "/create", OrganizationController, :create
    get "/select/:tenant_id", OrganizationController, :select
    post "/sync", OrganizationController, :sync_organizations
  end

  scope "/:tenant_id", GeoFleeticWeb do
    pipe_through [:browser, :authenticated, :tenant]

    live "/dashboard/:fleet_id", DashboardLive, :index
    live "/fleet/:fleet_id", DashboardLive, :fleet
    live "/map/:fleet_id", DashboardLive, :map
    live "/alerts/:fleet_id", DashboardLive, :alerts
    live "/dispatch/:fleet_id", DashboardLive, :dispatch
  end

  # API endpoints for external integrations
  scope "/api/:tenant_id", GeoFleeticWeb do
    pipe_through [:api, :authenticated, :tenant]

    post "/location/:vehicle_id", LocationController, :update
    post "/dispatch", DispatchController, :create
    get "/vehicles/:fleet_id", VehicleController, :index
    get "/geofences/:fleet_id", GeofenceController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", GeoFleeticWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:geo_fleetic, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GeoFleeticWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
