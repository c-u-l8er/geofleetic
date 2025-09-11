defmodule GeoFleetic.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :clerk_id, :string
    field :first_name, :string
    field :last_name, :string

    has_many :memberships, GeoFleetic.Membership
    has_many :tenants, through: [:memberships, :tenant]

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :clerk_id, :first_name, :last_name])
    |> validate_required([:email, :clerk_id])
    |> unique_constraint(:email)
    |> unique_constraint(:clerk_id)
  end
end
