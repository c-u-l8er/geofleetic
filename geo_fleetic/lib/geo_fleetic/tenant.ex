defmodule GeoFleetic.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :name, :string
    field :domain, :string
    field :clerk_org_id, :string  # Clerk organization ID

    has_many :memberships, GeoFleetic.Membership
    has_many :users, through: [:memberships, :user]
    has_many :fleets, GeoFleetic.Fleet

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :domain])
    |> validate_required([:name])
    |> unique_constraint(:domain)
  end
end
