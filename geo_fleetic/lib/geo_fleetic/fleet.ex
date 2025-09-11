defmodule GeoFleetic.Fleet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fleets" do
    field :name, :string

    belongs_to :tenant, GeoFleetic.Tenant

    timestamps()
  end

  @doc false
  def changeset(fleet, attrs) do
    fleet
    |> cast(attrs, [:name, :tenant_id])
    |> validate_required([:name, :tenant_id])
  end
end
