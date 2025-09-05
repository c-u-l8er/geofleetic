defmodule GeoFleeticWeb.GeofenceController do
  use GeoFleeticWeb, :controller
  use Stellarmorphism

  @moduledoc """
  API controller for geofence management.
  """

  def index(conn, %{"fleet_id" => fleet_id}) do
    # Get geofences for the fleet (placeholder - would query database)
    geofences = [
      %{
        id: "gf_001",
        name: "Downtown Zone",
        type: "static",
        boundary: %{
          type: "Polygon",
          coordinates: [[
            [-122.4194, 37.7749],
            [-122.4194, 37.7849],
            [-122.4094, 37.7849],
            [-122.4094, 37.7749],
            [-122.4194, 37.7749]
          ]]
        },
        active: true,
        breach_count: 5,
        last_breach: DateTime.utc_now()
      }
    ]

    conn
    |> put_status(:ok)
    |> json(%{geofences: geofences, count: length(geofences)})
  end

  def create(conn, %{"fleet_id" => fleet_id} = params) do
    # Create new geofence
    geofence = core StaticGeofence,
      boundary: parse_boundary(params["boundary"]),
      fence_type: params["type"] || :no_entry,
      hysteresis_buffer: params["hysteresis_buffer"] || 50.0,
      dwell_time_seconds: params["dwell_time_seconds"] || 30

    # TODO: Save to database
    # GeoFleetic.Repo.insert(geofence)

    # Log geofence creation
    GeoFleetic.Logger.log_fleet_event("geofence_created", %{fleet_id: fleet_id, geofence_id: "new_id"})

    conn
    |> put_status(:created)
    |> json(%{status: "success", message: "Geofence created successfully"})
  end

  defp parse_boundary(%{"type" => "Polygon", "coordinates" => coordinates}) do
    %Geo.Polygon{
      coordinates: coordinates,
      srid: 4326
    }
  end

  defp parse_boundary(%{"type" => "Point", "coordinates" => [lng, lat], "radius" => radius}) do
    # For circle geofences, create a simple square approximation
    # In a real implementation, you'd use proper circle-to-polygon conversion
    half_radius = radius / 111_000  # Rough conversion to degrees (very approximate)
    %Geo.Polygon{
      coordinates: [[
        [lng - half_radius, lat - half_radius],
        [lng + half_radius, lat - half_radius],
        [lng + half_radius, lat + half_radius],
        [lng - half_radius, lat + half_radius],
        [lng - half_radius, lat - half_radius]
      ]],
      srid: 4326
    }
  end
end
