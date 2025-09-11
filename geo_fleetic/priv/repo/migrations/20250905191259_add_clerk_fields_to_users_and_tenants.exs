defmodule GeoFleetic.Repo.Migrations.AddClerkFieldsToUsersAndTenants do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :clerk_id, :string
    end

    alter table(:tenants) do
      add :clerk_org_id, :string
    end

    create unique_index(:users, [:clerk_id])
    create unique_index(:tenants, [:clerk_org_id])
  end
end
