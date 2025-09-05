defmodule GeoFleeticWeb.VehicleController do
  use GeoFleeticWeb, :controller
  use Stellarmorphism

  @moduledoc """
  API controller for vehicle management.
  """

  def index(conn, %{"fleet_id" => fleet_id}) do
    # Get active vehicles for the fleet
    vehicles = GeoFleetic.SpatialQueries.vehicles_in_area(fleet_id, nil) || []

    # Convert to API format
    vehicle_data = Enum.map(vehicles, fn vehicle ->
      fission GeoFleetic.Vehicle, vehicle do
        core Vehicle, id: id, location: loc, status: status, vehicle_type: type ->
          %{
            id: id,
            location: geometry_to_geojson(loc),
            status: status,
            vehicle_type: type,
            last_updated: DateTime.utc_now()
          }
      end
    end)

    conn
    |> put_status(:ok)
    |> json(%{vehicles: vehicle_data, count: length(vehicle_data)})
  end

  defp geometry_to_geojson(%Geo.Point{coordinates: {lng, lat}}) do
    %{type: "Point", coordinates: [lng, lat]}
  end

  defp geometry_to_geojson(nil) do
    nil
  end
end
