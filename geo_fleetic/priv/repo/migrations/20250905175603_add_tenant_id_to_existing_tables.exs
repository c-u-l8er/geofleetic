defmodule GeoFleetic.Repo.Migrations.AddTenantIdToExistingTables do
  use Ecto.Migration

  def change do
    # Add tenant_id column as nullable first
    alter table(:geofences) do
      add :tenant_id, :bigint, null: true
    end

    # For now, just add the column and index - we'll handle tenant assignment in application code
    # This allows the migration to complete without requiring existing tenant data

    # Add indexes for performance
    create index(:geofences, [:tenant_id])
  end
end
