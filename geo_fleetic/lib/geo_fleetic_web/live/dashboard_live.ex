defmodule GeoFleeticWeb.DashboardLive do
  @moduledoc """
  Real-time fleet dashboard with LiveView.

  Features:
  - Live map visualization
  - Real-time performance metrics
  - Interactive geofence management
  - Alert monitoring and management
  - Route tracking and optimization
  """

  use Phoenix.LiveView
  use Stellarmorphism

  @impl true
  def mount(%{"fleet_id" => fleet_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "fleet_events:#{fleet_id}")
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "vehicle_locations:#{fleet_id}")

      # Set up periodic metrics updates
      :timer.send_interval(5000, :update_metrics)
    end

    # Load initial dashboard state using stellar types
    initial_state = core DashboardState,
      fleet_id: fleet_id,
      active_vehicles: load_active_vehicles(fleet_id),
      recent_events: load_recent_events(fleet_id),
      geofence_status: load_geofence_status(fleet_id),
      performance_metrics: calculate_initial_metrics(fleet_id),
      alert_counts: %{},
      last_updated: DateTime.utc_now()

    # Add mock alerts for demonstration
    initial_state = %{initial_state | alert_counts: %{
      "speed_violation" => 3,
      "geofence_entry" => 2,
      "route_deviation" => 1
    }}

    {:ok, assign(socket, dashboard_state: initial_state, current_view: :index)}
  end

  @impl true
  def handle_params(%{"fleet_id" => _fleet_id}, _uri, socket) do
    current_view = case socket.assigns.live_action do
      :index -> :index
      :fleet -> :fleet
      :map -> :map
      :alerts -> :alerts
      :dispatch -> :dispatch
      _ -> :index
    end
    {:noreply, assign(socket, current_view: current_view)}
  end

  @impl true
  def handle_info({:location_update, vehicle_updates}, socket) do
    dashboard_state = socket.assigns.dashboard_state

    # Update vehicle positions
    updated_vehicles = Enum.map(dashboard_state.active_vehicles, fn vehicle ->
      case Enum.find(vehicle_updates, &(&1.vehicle_id == vehicle.id)) do
        nil -> vehicle
        update -> Map.put(vehicle, :location, update.location)
      end
    end)

    updated_state = %{dashboard_state | active_vehicles: updated_vehicles, last_updated: DateTime.utc_now()}

    {:noreply, assign(socket, dashboard_state: updated_state)}
  end

  @impl true
  def handle_info({:geofence_breach, breach_event}, socket) do
    dashboard_state = socket.assigns.dashboard_state

    # Update geofence status
    updated_status = Map.update(dashboard_state.geofence_status, breach_event.geofence_id,
      %{breach_count: 1, last_breach: DateTime.utc_now()},
      fn status ->
        %{status |
          breach_count: status.breach_count + 1,
          last_breach: DateTime.utc_now()
        }
      end)

    # Update alert counts
    alert_key = "#{breach_event.breach_type}_breach"
    updated_alerts = Map.update(dashboard_state.alert_counts, alert_key, 1, &(&1 + 1))

    updated_state = %{dashboard_state |
      geofence_status: updated_status,
      alert_counts: updated_alerts
    }

    # Push real-time alert to client
    push_event(socket, "geofence_alert", %{
      vehicle_id: breach_event.vehicle_id,
      geofence_id: breach_event.geofence_id,
      type: breach_event.breach_type,
      location: geometry_to_geojson(breach_event.location)
    })

    {:noreply, assign(socket, dashboard_state: updated_state)}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    dashboard_state = socket.assigns.dashboard_state

    # Calculate updated metrics
    vehicles = dashboard_state.active_vehicles
    metrics = %{
      total_vehicles: length(vehicles),
      active_count: length(vehicles), # Simplified for now
      average_speed: 45.5, # Mock data
      fuel_efficiency: 8.5, # Mock data
      on_time_performance: 0.92, # Mock data
      alert_count: map_size(dashboard_state.alert_counts)
    }

    updated_state = %{dashboard_state | performance_metrics: metrics}

    {:noreply, assign(socket, dashboard_state: updated_state)}
  end

  @impl true
  def handle_event("create_geofence", _params, socket) do
    # Create new geofence
    # TODO: Implement geofence creation
    {:noreply, socket}
  end

  @impl true
  def handle_event("dispatch_vehicle", _params, socket) do
    # Dispatch vehicle to location
    # TODO: Implement vehicle dispatch
    {:noreply, socket}
  end

  @impl true
  def handle_event("acknowledge_alert", %{"alert_id" => alert_id}, socket) do
    dashboard_state = socket.assigns.dashboard_state

    # Acknowledge alert by removing it from counts
    updated_alerts = Map.delete(dashboard_state.alert_counts, alert_id)
    updated_state = %{dashboard_state | alert_counts: updated_alerts}

    {:noreply, assign(socket, dashboard_state: updated_state)}
  end

  @impl true
  def render(assigns) do
    vehicles_json = Jason.encode!(assigns.dashboard_state.active_vehicles)
    geofences_json = Jason.encode!(load_geofence_boundaries(assigns.dashboard_state.fleet_id))

    ~H"""
    <!-- Include Leaflet CSS and JS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">
            <%= get_page_title(@current_view) %>
          </h1>
          <p class="mt-2 text-sm text-gray-600">
            <%= get_page_description(@current_view) %>
          </p>

          <!-- Navigation -->
          <nav class="mt-6">
            <div class="flex space-x-4">
              <%= live_patch "Dashboard", to: "/dashboard/#{@dashboard_state.fleet_id}", class: "px-3 py-2 rounded-md text-sm font-medium #{if @current_view == :index, do: "bg-blue-100 text-blue-700", else: "text-gray-500 hover:text-gray-700"}" %>
              <%= live_patch "Fleet", to: "/fleet/#{@dashboard_state.fleet_id}", class: "px-3 py-2 rounded-md text-sm font-medium #{if @current_view == :fleet, do: "bg-blue-100 text-blue-700", else: "text-gray-500 hover:text-gray-700"}" %>
              <%= live_patch "Map", to: "/map/#{@dashboard_state.fleet_id}", class: "px-3 py-2 rounded-md text-sm font-medium #{if @current_view == :map, do: "bg-blue-100 text-blue-700", else: "text-gray-500 hover:text-gray-700"}" %>
              <%= live_patch "Alerts", to: "/alerts/#{@dashboard_state.fleet_id}", class: "px-3 py-2 rounded-md text-sm font-medium #{if @current_view == :alerts, do: "bg-blue-100 text-blue-700", else: "text-gray-500 hover:text-gray-700"}" %>
              <%= live_patch "Dispatch", to: "/dispatch/#{@dashboard_state.fleet_id}", class: "px-3 py-2 rounded-md text-sm font-medium #{if @current_view == :dispatch, do: "bg-blue-100 text-blue-700", else: "text-gray-500 hover:text-gray-700"}" %>
            </div>
          </nav>
        </div>

        <!-- Real-time Metrics -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                    <span class="text-white text-sm font-medium">🚗</span>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Active Vehicles</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @dashboard_state.performance_metrics.active_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                    <span class="text-white text-sm font-medium">📊</span>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Avg Speed</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @dashboard_state.performance_metrics.average_speed %> km/h</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                    <span class="text-white text-sm font-medium">⚡</span>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Fuel Efficiency</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @dashboard_state.performance_metrics.fuel_efficiency %> L/100km</dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
                    <span class="text-white text-sm font-medium">🚨</span>
                  </div>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Active Alerts</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @dashboard_state.performance_metrics.alert_count %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Map Section -->
        <%= if @current_view in [:index, :map] do %>
          <div class="bg-white shadow rounded-lg mb-8">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  <%= if @current_view == :map do %>Interactive Fleet Map<% else %>Live Fleet Map<% end %>
                </h3>
                <%= if @current_view == :map do %>
                  <div class="flex space-x-2">
                    <button class="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600" phx-click="add_geofence">
                      Add Geofence
                    </button>
                    <button class="px-3 py-1 bg-green-500 text-white text-sm rounded hover:bg-green-600" phx-click="track_vehicle">
                      Track Vehicle
                    </button>
                  </div>
                <% end %>
              </div>
              <.live_component
                module={GeoFleeticWeb.MapComponent}
                id="fleet-map"
                fleet_id={@dashboard_state.fleet_id}
                vehicles={@dashboard_state.active_vehicles}
                geofences={load_geofence_boundaries(@dashboard_state.fleet_id)}
              />
            </div>
          </div>
        <% end %>

        <!-- Fleet Management Section -->
        <%= if @current_view in [:index, :fleet] do %>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
            <!-- Vehicle List -->
            <div class="bg-white shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex justify-between items-center mb-4">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">Active Vehicles</h3>
                  <button class="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600">
                    Add Vehicle
                  </button>
                </div>
                <div class="space-y-3">
                  <%= if Enum.empty?(@dashboard_state.active_vehicles) do %>
                    <div class="text-center py-8">
                      <div class="text-4xl mb-4">🚗</div>
                      <p class="text-gray-500">No active vehicles</p>
                      <p class="text-sm text-gray-400 mt-2">Vehicles will appear here when online</p>
                    </div>
                  <% else %>
                    <%= for vehicle <- @dashboard_state.active_vehicles do %>
                      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <div class="flex items-center space-x-3">
                          <div class="w-3 h-3 bg-green-400 rounded-full"></div>
                          <div>
                            <p class="text-sm font-medium text-gray-900">Vehicle <%= vehicle.id %></p>
                            <p class="text-xs text-gray-500">Speed: <%= vehicle.speed || 0 %> km/h</p>
                          </div>
                        </div>
                        <div class="flex space-x-2">
                          <button class="px-2 py-1 text-xs bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
                            Track
                          </button>
                          <button class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200">
                            Stop
                          </button>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Geofence Management -->
            <div class="bg-white shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex justify-between items-center mb-4">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">Geofence Management</h3>
                  <button class="px-3 py-1 bg-green-500 text-white text-sm rounded hover:bg-green-600">
                    Create Geofence
                  </button>
                </div>
                <div class="space-y-3">
                  <%= if Enum.empty?(@dashboard_state.geofence_status) do %>
                    <div class="text-center py-8">
                      <div class="text-4xl mb-4">⭕</div>
                      <p class="text-gray-500">No active geofences</p>
                      <p class="text-sm text-gray-400 mt-2">Create geofences to monitor vehicle activity</p>
                    </div>
                  <% else %>
                    <%= for {geofence_id, geofence} <- @dashboard_state.geofence_status do %>
                      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <div class="flex items-center space-x-3">
                          <div class="w-3 h-3 bg-green-400 rounded-full"></div>
                          <div>
                            <p class="text-sm font-medium text-gray-900"><%= geofence.name %></p>
                            <p class="text-xs text-gray-500">Type: <%= geofence.type %></p>
                          </div>
                        </div>
                        <div class="flex space-x-2">
                          <button class="px-2 py-1 text-xs bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
                            Edit
                          </button>
                          <button class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200">
                            Delete
                          </button>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Dispatch Controls -->
        <%= if @current_view == :dispatch do %>
          <div class="bg-white shadow rounded-lg mb-8">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Dispatch Center</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h4 class="text-md font-medium text-gray-900 mb-3">New Dispatch Request</h4>
                  <form class="space-y-3">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Pickup Location</label>
                      <input type="text" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm" placeholder="Enter address or coordinates">
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Service Type</label>
                      <select class="mt-1 block w-full border-gray-300 rounded-md shadow-sm">
                        <option>Standard</option>
                        <option>Emergency</option>
                        <option>Priority</option>
                      </select>
                    </div>
                    <button type="submit" class="w-full bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600">
                      Dispatch Vehicle
                    </button>
                  </form>
                </div>
                <div>
                  <h4 class="text-md font-medium text-gray-900 mb-3">Active Dispatches</h4>
                  <div class="space-y-2">
                    <div class="text-center py-8">
                      <div class="text-4xl mb-4">📋</div>
                      <p class="text-gray-500">No active dispatches</p>
                      <p class="text-sm text-gray-400 mt-2">New dispatches will appear here</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Alert Management -->
        <%= if @current_view == :alerts do %>
          <div class="bg-white shadow rounded-lg mb-8">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Alert Management</h3>
              <div class="space-y-4">
                <%= if @dashboard_state.alert_counts == %{} do %>
                  <div class="text-center py-8">
                    <div class="text-4xl mb-4">🔔</div>
                    <p class="text-gray-500">No active alerts</p>
                    <p class="text-sm text-gray-400 mt-2">Alerts will appear here when triggered</p>
                  </div>
                <% else %>
                  <%= for {alert_type, count} <- @dashboard_state.alert_counts do %>
                    <div class="flex items-center justify-between p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
                      <div class="flex items-center space-x-3">
                        <div class="w-3 h-3 bg-yellow-400 rounded-full"></div>
                        <div>
                          <p class="text-sm font-medium text-gray-900"><%= String.capitalize(alert_type) %></p>
                          <p class="text-xs text-gray-500"><%= count %> occurrences</p>
                        </div>
                      </div>
                      <button class="px-3 py-1 text-xs bg-yellow-100 text-yellow-700 rounded hover:bg-yellow-200">
                        Acknowledge
                      </button>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Recent Events -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Events</h3>
            <div class="space-y-4">
              <%= if Enum.empty?(@dashboard_state.recent_events) do %>
                <div class="text-center py-8">
                  <div class="text-4xl mb-4">📡</div>
                  <p class="text-gray-500">No recent events</p>
                  <p class="text-sm text-gray-400 mt-2">Events will appear here in real-time</p>
                </div>
              <% else %>
                <%= for event <- @dashboard_state.recent_events do %>
                  <div class="flex items-center space-x-3">
                    <div class="flex-shrink-0">
                      <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                        <span class="text-blue-600 text-sm">📍</span>
                      </div>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900">Location Update</p>
                      <p class="text-sm text-gray-500">Vehicle position updated</p>
                    </div>
                    <div class="flex-shrink-0 text-sm text-gray-500">
                      <%= Calendar.strftime(DateTime.utc_now(), "%H:%M:%S") %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Connection Status -->
        <div class="mt-8 bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">System Status</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div class="text-center">
                <div class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  <span class="w-2 h-2 bg-green-400 rounded-full mr-1.5"></span>
                  WebSocket Connected
                </div>
              </div>
              <div class="text-center">
                <div class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  <span class="w-2 h-2 bg-green-400 rounded-full mr-1.5"></span>
                  Database Connected
                </div>
              </div>
              <div class="text-center">
                <div class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  <span class="w-2 h-2 bg-green-400 rounded-full mr-1.5"></span>
                  Real-time Processing Active
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_page_title(:index), do: "Fleet Dashboard"
  defp get_page_title(:fleet), do: "Fleet Overview"
  defp get_page_title(:map), do: "Live Fleet Map"
  defp get_page_title(:alerts), do: "Alert Management"
  defp get_page_title(:dispatch), do: "Dispatch Center"

  defp get_page_description(:index), do: "Real-time fleet monitoring and management"
  defp get_page_description(:fleet), do: "Complete fleet status and vehicle tracking"
  defp get_page_description(:map), do: "Interactive map with real-time vehicle positions"
  defp get_page_description(:alerts), do: "Monitor and manage fleet alerts"
  defp get_page_description(:dispatch), do: "Intelligent vehicle dispatch and routing"

  defp load_active_vehicles(_fleet_id) do
    # Mock data for demonstration
    [
      %{id: "V001", speed: 45.5, status: "active", location: %{lat: 37.7749, lng: -122.4194}},
      %{id: "V002", speed: 32.1, status: "active", location: %{lat: 37.7849, lng: -122.4094}},
      %{id: "V003", speed: 28.7, status: "active", location: %{lat: 37.7649, lng: -122.4294}},
      %{id: "V004", speed: 52.3, status: "active", location: %{lat: 37.7549, lng: -122.4394}}
    ]
  end

  defp load_recent_events(_fleet_id) do
    # TODO: Load recent events from database
    []
  end

  defp load_geofence_status(_fleet_id) do
    # Load geofence data from database
    try do
      # Use raw SQL to avoid geometry type decoding issues
      result = Ecto.Adapters.SQL.query!(GeoFleetic.Repo,
        "SELECT id, name, geofence_type FROM geofences",
        [])

      # Convert to map format expected by dashboard
      Enum.reduce(result.rows, %{}, fn [id, name, type], acc ->
        Map.put(acc, id, %{
          name: name,
          type: type,
          breach_count: 0,
          last_breach: nil
        })
      end)
    rescue
      _error ->
        # Return empty map if query fails
        %{}
    end
  end

  defp calculate_initial_metrics(_fleet_id) do
    # TODO: Calculate initial metrics
    %{
      total_vehicles: 0,
      active_count: 0,
      average_speed: 0.0,
      fuel_efficiency: 0.0,
      on_time_performance: 0.0,
      alert_count: 0
    }
  end

  defp geometry_to_geojson(%Geo.Point{coordinates: {lng, lat}}) do
    %{
      type: "Point",
      coordinates: [lng, lat]
    }
  end

  defp geometry_to_geojson(%Geo.Polygon{coordinates: coordinates}) do
    %{
      type: "Polygon",
      coordinates: coordinates
    }
  end

  defp load_geofence_boundaries(_fleet_id) do
    # Load geofence boundary data from database
    try do
      # Use raw SQL to get geofence boundaries as GeoJSON
      result = Ecto.Adapters.SQL.query!(GeoFleetic.Repo,
        "SELECT id, name, geofence_type, ST_AsGeoJSON(boundary) as boundary_geojson FROM geofences",
        [])

      # Convert to format expected by map component
      Enum.map(result.rows, fn [id, name, type, boundary_json] ->
        %{
          id: id,
          name: name,
          type: type,
          boundary: Jason.decode!(boundary_json)
        }
      end)
    rescue
      _error ->
        # Return empty list if query fails
        []
    end
  end
end
