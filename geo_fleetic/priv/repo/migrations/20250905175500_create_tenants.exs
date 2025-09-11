defmodule GeoFleetic.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants) do
      add :name, :string, null: false
      add :domain, :string
      timestamps()
    end

    create unique_index(:tenants, [:domain])

    create table(:users) do
      add :email, :string, null: false
      add :workos_id, :string, null: false
      add :first_name, :string
      add :last_name, :string
      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:workos_id])

    create table(:memberships) do
      add :role, :string, default: "member", null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:memberships, [:user_id, :tenant_id])

    create table(:fleets) do
      add :name, :string, null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      timestamps()
    end
  end
end
