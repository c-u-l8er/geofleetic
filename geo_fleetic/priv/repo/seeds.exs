# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     GeoFleetic.Repo.insert!(%GeoFleetic.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias GeoFleetic.{Repo, Tenant, User, Membership, Fleet}

# Create demo tenant
tenant = Repo.insert!(%Tenant{
  name: "Demo Logistics Company",
  domain: "demo.example.com"
})

# Create demo user (matches the auth controller)
user = Repo.insert!(%User{
  email: "demo@example.com",
  workos_id: "demo_user_123",
  first_name: "Demo",
  last_name: "User"
})

# Create membership
Repo.insert!(%Membership{
  user_id: user.id,
  tenant_id: tenant.id,
  role: "admin"
})

# Create demo fleet
Repo.insert!(%Fleet{
  name: "Main Fleet",
  tenant_id: tenant.id
})

IO.puts("Demo data created successfully!")
IO.puts("Tenant: #{tenant.name}")
IO.puts("User: #{user.email}")
IO.puts("Fleet: Main Fleet")
