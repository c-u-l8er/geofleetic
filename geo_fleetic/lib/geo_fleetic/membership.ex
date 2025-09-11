defmodule GeoFleetic.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memberships" do
    field :role, :string, default: "member"

    belongs_to :user, GeoFleetic.User
    belongs_to :tenant, GeoFleetic.Tenant

    timestamps()
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :user_id, :tenant_id])
    |> validate_required([:role, :user_id, :tenant_id])
    |> validate_inclusion(:role, ["admin", "member"])
    |> unique_constraint([:user_id, :tenant_id])
  end
end
