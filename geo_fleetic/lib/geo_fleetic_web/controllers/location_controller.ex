defmodule GeoFleeticWeb.LocationController do
  use GeoFleeticWeb, :controller
  use Stellarmorphism

  @moduledoc """
  API controller for handling location updates from vehicles.
  """

  def update(conn, %{"vehicle_id" => vehicle_id} = params) do
    # Create stellar location update event
    location_update = core VehicleLocationUpdate,
      vehicle_id: vehicle_id,
      location: %Geo.Point{
        coordinates: {params["lng"], params["lat"]},
        srid: 4326
      },
      timestamp: DateTime.utc_now(),
      speed: params["speed"] || 0.0,
      heading: params["heading"] || 0.0,
      accuracy: params["accuracy"] || 10.0

    # Process through real-time engine
    GeoFleetic.RealtimeProcessor.process_location_update(location_update)

    # Log the location update
    GeoFleetic.Logger.log_vehicle_location(vehicle_id, location_update.location,
      speed: location_update.speed,
      heading: location_update.heading,
      accuracy: location_update.accuracy
    )

    conn
    |> put_status(:ok)
    |> json(%{status: "success", vehicle_id: vehicle_id})
  end
end
