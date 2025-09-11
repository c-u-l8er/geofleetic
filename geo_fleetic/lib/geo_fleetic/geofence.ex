defmodule GeoFleetic.Geofence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "geofences" do
    field :name, :string
    field :boundary, Geo.PostGIS.Geometry
    field :geofence_type, :string, default: "static"
    field :hysteresis_buffer, :float, default: 50.0
    field :dwell_time_seconds, :integer, default: 30
    field :active_schedule, :map
    field :conditions, :map
    field :logical_operator, :string, default: "and"
    field :ml_model_id, :string
    field :prediction_window_minutes, :integer, default: 15
    field :confidence_threshold, :float, default: 0.8
    field :trigger_conditions, :map

    belongs_to :tenant, GeoFleetic.Tenant

    timestamps()
  end

  @doc false
  def changeset(geofence, attrs) do
    geofence
    |> cast(attrs, [:id, :name, :boundary, :geofence_type, :hysteresis_buffer, :dwell_time_seconds, :active_schedule, :conditions, :logical_operator, :ml_model_id, :prediction_window_minutes, :confidence_threshold, :trigger_conditions])
    |> validate_required([:id, :name, :boundary])
  end
end
