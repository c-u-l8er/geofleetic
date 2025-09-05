defmodule GeoFleeticWeb.MapComponent do
  @moduledoc """
  Real-time map component for fleet visualization.

  Displays vehicles, geofences, routes, and real-time updates.
  """

  use Phoenix.LiveComponent
  use Stellarmorphism

  @impl true
  def mount(socket) do
    # Subscribe to real-time updates
    fleet_id = socket.assigns[:fleet_id]
    if connected?(socket) and fleet_id do
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "vehicle_locations:#{fleet_id}")
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "geofence_alerts:#{fleet_id}")
    end

    {:ok, assign(socket, %{
      vehicles: socket.assigns[:vehicles] || [],
      geofences: socket.assigns[:geofences] || [],
      routes: [],
      selected_vehicle: nil,
      map_center: {-122.4194, 37.7749}, # Default to San Francisco
      zoom_level: 12,
      real_time_enabled: true
    })}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Update vehicles and geofences from parent assigns
    vehicles = assigns[:vehicles] || socket.assigns.vehicles
    geofences = assigns[:geofences] || socket.assigns.geofences

    {:ok, assign(socket, vehicles: vehicles, geofences: geofences)}
  end

  @impl true
  def handle_event("vehicle_selected", %{"vehicle_id" => vehicle_id}, socket) do
    selected_vehicle = Enum.find(socket.assigns.vehicles, &(&1.id == vehicle_id))
    {:noreply, assign(socket, selected_vehicle: selected_vehicle)}
  end

  @impl true
  def handle_event("geofence_selected", %{"geofence_id" => geofence_id}, socket) do
    # TODO: Handle geofence selection
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_real_time", _params, socket) do
    {:noreply, assign(socket, real_time_enabled: !socket.assigns.real_time_enabled)}
  end

  @impl true
  def handle_event("center_on_vehicle", %{"vehicle_id" => vehicle_id}, socket) do
    vehicle = Enum.find(socket.assigns.vehicles, &(&1.id == vehicle_id))
    if vehicle do
      {:noreply, assign(socket, map_center: vehicle.location.coordinates)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:location_update, location_data}, socket) do
    if socket.assigns.real_time_enabled do
      updated_vehicles = update_vehicle_positions(socket.assigns.vehicles, location_data)
      {:noreply, assign(socket, vehicles: updated_vehicles)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:geofence_alert, alert_data}, socket) do
    # Highlight geofence that triggered alert
    {:noreply, push_event(socket, "highlight_geofence", %{
      geofence_id: alert_data.geofence_id,
      alert_type: alert_data.type
    })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-[600px] w-full flex flex-col">

      <!-- Map and Sidebar Container -->
      <div class="flex flex-1 min-h-0 w-full">
        <!-- Map Container -->
        <div class="w-4/5 relative">
          <div id="map-container" class="h-full w-full bg-gray-100" phx-hook="FleetMap" data-vehicles={Jason.encode!(@vehicles)} data-geofences={Jason.encode!(@geofences)}>
            <!-- Map will be rendered here by JavaScript -->
            <div class="flex items-center justify-center h-full">
              <div class="text-center">
                <div class="text-6xl mb-4">🗺️</div>
                <p class="text-gray-600 mb-2">Interactive Fleet Map</p>
                <p class="text-sm text-gray-400">Real-time vehicle tracking</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Vehicle List Sidebar -->
        <div class="w-1/5 bg-white border-l border-gray-200 p-4 overflow-y-auto">
          <h3 class="text-lg font-medium text-gray-900 mb-3">Active Vehicles</h3>
          <div class="space-y-2">
            <%= for vehicle <- @vehicles do %>
              <div
                class="flex items-center space-x-3 p-2 rounded-md hover:bg-gray-50 cursor-pointer"
                phx-click="vehicle_selected"
                phx-value-vehicle_id={vehicle.id}
              >
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-900 truncate"><%= vehicle.id %></p>
                  <p class="text-xs text-gray-500">
                    <%= format_coordinates(vehicle.location) %>
                  </p>
                </div>
                <button
                  class="text-xs text-blue-600 hover:text-blue-800"
                  phx-click="center_on_vehicle"
                  phx-value-vehicle_id={vehicle.id}
                >
                  📍
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Selected Vehicle Details -->
      <%= if @selected_vehicle do %>
        <div class="bg-white border-t border-gray-200 p-4">
          <h4 class="text-lg font-medium text-gray-900 mb-2">Vehicle Details</h4>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div><strong>ID:</strong> <%= @selected_vehicle.id %></div>
            <div><strong>Status:</strong> <%= @selected_vehicle.status %></div>
            <div><strong>Speed:</strong> <%= @selected_vehicle.speed %> km/h</div>
            <div><strong>Location:</strong> <%= format_coordinates(@selected_vehicle.location) %></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp update_vehicle_positions(vehicles, location_updates) do
    Enum.map(vehicles, fn vehicle ->
      case Enum.find(location_updates, &(&1.vehicle_id == vehicle.id)) do
        nil -> vehicle
        update ->
          %{vehicle |
            location: update.location,
            speed: update.speed,
            heading: update.heading,
            last_seen: DateTime.utc_now()
          }
      end
    end)
  end

  defp format_coordinates(%{coordinates: {lng, lat}}) do
    "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"
  end

  defp format_coordinates(%{lat: lat, lng: lng}) do
    "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
