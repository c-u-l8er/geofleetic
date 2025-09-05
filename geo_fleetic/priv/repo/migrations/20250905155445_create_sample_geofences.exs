defmodule GeoFleetic.Repo.Migrations.CreateSampleGeofences do
  use Ecto.Migration

  def change do
    # Insert sample geofences for demonstration
    execute("""
    INSERT INTO geofences (id, name, boundary, geofence_type, inserted_at, updated_at) VALUES
    ('gf-001', 'Downtown SF', ST_GeomFromText('POLYGON((-122.42 37.78, -122.40 37.78, -122.40 37.76, -122.42 37.76, -122.42 37.78))', 4326), 'static', NOW(), NOW()),
    ('gf-002', 'Golden Gate Park', ST_GeomFromText('POLYGON((-122.51 37.78, -122.45 37.78, -122.45 37.74, -122.51 37.74, -122.51 37.78))', 4326), 'static', NOW(), NOW()),
    ('gf-003', 'Airport Zone', ST_GeomFromText('POLYGON((-122.39 37.62, -122.37 37.62, -122.37 37.60, -122.39 37.60, -122.39 37.62))', 4326), 'static', NOW(), NOW()),
    ('gf-004', 'Speed Zone A', ST_GeomFromText('POLYGON((-122.43 37.77, -122.41 37.77, -122.41 37.75, -122.43 37.75, -122.43 37.77))', 4326), 'static', NOW(), NOW()),
    ('gf-005', 'Construction Area', ST_GeomFromText('POLYGON((-122.44 37.79, -122.42 37.79, -122.42 37.77, -122.44 37.77, -122.44 37.79))', 4326), 'static', NOW(), NOW());
    """)
  end
end
