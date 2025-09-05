defmodule GeoFleetic.Repo.Migrations.CreateGeofences do
  use Ecto.Migration

  def change do
    create table(:geofences, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :boundary, :geometry, null: false
      add :geofence_type, :string, default: "static"
      add :hysteresis_buffer, :float, default: 50.0
      add :dwell_time_seconds, :integer, default: 30
      add :active_schedule, :map
      add :conditions, :map
      add :logical_operator, :string, default: "and"
      add :ml_model_id, :string
      add :prediction_window_minutes, :integer, default: 15
      add :confidence_threshold, :float, default: 0.8
      add :trigger_conditions, :map

      timestamps()
    end

    create index(:geofences, [:boundary], using: :gist)
  end
end
