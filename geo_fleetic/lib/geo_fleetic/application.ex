defmodule GeoFleetic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GeoFleeticWeb.Telemetry,
      GeoFleetic.Repo,
      {DNSCluster, query: Application.get_env(:geo_fleetic, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GeoFleetic.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: GeoFleetic.Finch},
      # Start the real-time processor for location updates
      GeoFleetic.RealtimeProcessor,
      # Start to serve requests, typically the last entry
      GeoFleeticWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GeoFleetic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GeoFleeticWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
