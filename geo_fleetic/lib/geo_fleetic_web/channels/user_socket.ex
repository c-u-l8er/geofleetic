defmodule GeoFleeticWeb.UserSocket do
  use Phoenix.Socket

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  channel "fleet:*", GeoFleeticWeb.FleetChannel
  channel "vehicle:*", GeoFleeticWeb.FleetChannel
  channel "geofence:*", GeoFleeticWeb.FleetChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
