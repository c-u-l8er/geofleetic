defmodule GeoFleeticWeb.FleetChannel do
  use Phoenix.Channel
  use Stellarmorphism

  alias Geo.Point
  alias Geo.Polygon

  @moduledoc """
  Real-time WebSocket channel for fleet communication.

  Topics:
  - "fleet:{fleet_id}" - Fleet-wide events and queries
  - "vehicle:{vehicle_id}" - Specific vehicle updates
  - "geofence:{geofence_id}" - Geofence breach notifications
  """

  def join("fleet:" <> fleet_id, _payload, socket) do
    # Subscribe to fleet-wide events
    Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "fleet_events:#{fleet_id}")
    Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "vehicle_locations:#{fleet_id}")
    Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "geofence_alerts:#{fleet_id}")

    {:ok, assign(socket, :fleet_id, fleet_id)}
  end

  def join("vehicle:" <> vehicle_id, _payload, socket) do
    # Subscribe to specific vehicle updates
    Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "vehicle:#{vehicle_id}")

    {:ok, assign(socket, :vehicle_id, vehicle_id)}
  end

  def join("geofence:" <> geofence_id, _payload, socket) do
    # Subscribe to geofence breach events
    Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "geofence:#{geofence_id}")

    {:ok, assign(socket, :geofence_id, geofence_id)}
  end

  # Location Update Handling
  def handle_in("location_update", payload, socket) do
    vehicle_id = socket.assigns.vehicle_id

    # Create stellar location update event
    location_update = core VehicleLocationUpdate,
      vehicle_id: vehicle_id,
      location: %Point{
        coordinates: {payload["lng"], payload["lat"]},
        srid: 4326
      },
      timestamp: DateTime.utc_now(),
      speed: payload["speed"],
      heading: payload["heading"],
      accuracy: payload["accuracy"]

    # Process through real-time engine
    GeoFleetic.RealtimeProcessor.process_location_update(location_update)

    {:noreply, socket}
  end

  # Real-Time Query Support
  def handle_in("query", %{"type" => "vehicles_in_area"} = payload, socket) do
    fleet_id = socket.assigns.fleet_id

    # Parse boundary from payload
    boundary = parse_boundary(payload["boundary"])

    # Query vehicles in area using stellar types
    vehicles = GeoFleetic.SpatialQueries.vehicles_in_area(fleet_id, boundary)
    |> Enum.map(&stellar_vehicle_to_map/1)

    {:reply, {:ok, %{vehicles: vehicles}}, socket}
  end

  def handle_in("query", %{"type" => "route_status"} = payload, socket) do
    route_id = payload["route_id"]

    # Get live route status
    status = GeoFleetic.RouteManager.get_live_route_status(route_id)
    |> stellar_route_status_to_map()

    {:reply, {:ok, status}, socket}
  end

  # Event Broadcasting
  def handle_info({:fleet_event, event}, socket) do
    # Use stellar pattern matching to transform events
    event_data = fission GeoFleetic.FleetEvent, event do
      core VehicleLocationUpdate, vehicle_id: id, location: loc, speed: s, heading: h ->
        %{
          type: "location_update",
          vehicle_id: id,
          location: geometry_to_geojson(loc),
          speed: s,
          heading: h,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

      core GeofenceBreach, vehicle_id: v_id, geofence_id: g_id, breach_type: type ->
        %{
          type: "geofence_breach",
          vehicle_id: v_id,
          geofence_id: g_id,
          breach_type: type,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

      core RouteDeviation, vehicle_id: v_id, route_id: r_id, deviation_distance: dist ->
        %{
          type: "route_deviation",
          vehicle_id: v_id,
          route_id: r_id,
          deviation_distance: dist,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

      core EmergencyAlert, vehicle_id: v_id, alert_type: type, severity: sev ->
        %{
          type: "emergency_alert",
          vehicle_id: v_id,
          alert_type: type,
          severity: sev,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
    end

    # Broadcast to client
    push(socket, "event", event_data)
    {:noreply, socket}
  end

  # Helper functions
  defp parse_boundary(%{"type" => "polygon", "coordinates" => coordinates}) do
    %Polygon{
      coordinates: [coordinates],
      srid: 4326
    }
  end

  # For now, only support polygon boundaries
  defp parse_boundary(_), do: nil

  defp stellar_vehicle_to_map(vehicle) do
    fission GeoFleetic.Vehicle, vehicle do
      core Vehicle, id: id, location: loc, status: status, vehicle_type: type ->
        %{
          id: id,
          location: geometry_to_geojson(loc),
          status: status,
          vehicle_type: type
        }
    end
  end

  defp stellar_route_status_to_map(route_status) do
    fission GeoFleetic.RouteStatus, route_status do
      core RouteStatus, route_id: r_id, progress: prog, eta: eta, status: stat ->
        %{
          route_id: r_id,
          progress: prog,
          eta: eta,
          status: stat
        }
    end
  end

  defp geometry_to_geojson(%Point{coordinates: {lng, lat}}) do
    %{
      type: "Point",
      coordinates: [lng, lat]
    }
  end

  defp geometry_to_geojson(%Polygon{coordinates: coordinates}) do
    %{
      type: "Polygon",
      coordinates: coordinates
    }
  end
end
