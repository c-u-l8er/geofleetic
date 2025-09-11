defmodule GeoFleetic.VehicleLocation do
  use Ecto.Schema

  schema "vehicle_locations" do
    field :vehicle_id, :string
    field :location, Geo.PostGIS.Geometry
    field :speed, :float
    field :heading, :float
    field :accuracy, :float

    belongs_to :tenant, GeoFleetic.Tenant

    timestamps()
  end
end
