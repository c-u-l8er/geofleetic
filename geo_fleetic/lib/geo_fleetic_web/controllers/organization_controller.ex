defmodule GeoFleeticWeb.OrganizationController do
  use GeoFleeticWeb, :controller
  import Ecto.Query
  alias GeoFleetic.{User, Membership, Tenant, Repo}

  def manage(conn, _params) do
    user_id = get_session(conn, :user_id)
    user = Repo.get!(User, user_id)

    # Get user's organizations
    user_tenants = Repo.all(
      from t in Tenant,
      join: m in Membership,
      on: m.tenant_id == t.id,
      where: m.user_id == ^user.id,
      select: %{tenant: t, role: m.role}
    )

    # Debug: Log the organizations found
    IO.inspect(user_tenants, label: "User organizations")

    render(conn, :manage, user: user, organizations: user_tenants)
  end

  def sync_organizations(conn, _params) do
    user_id = get_session(conn, :user_id)
    user = Repo.get!(User, user_id)

    # Debug: Log user info
    IO.inspect(user.clerk_id, label: "User Clerk ID")

    # Clean up old default organizations that shouldn't exist
    cleanup_default_organizations(user)

    # Fetch organizations dynamically from Clerk
    # In a real implementation, this would make an API call to Clerk
    clerk_organizations = fetch_user_organizations_from_clerk(user, conn)

    # Debug: Log fetched organizations
    IO.inspect(clerk_organizations, label: "Fetched Clerk organizations")

    created_count = 0
    updated_count = 0

    for org <- clerk_organizations do
      # Check if tenant already exists
      case Repo.get_by(Tenant, clerk_org_id: org["id"]) do
        nil ->
          # Create new tenant
          tenant = Repo.insert!(%Tenant{
            name: org["name"],
            clerk_org_id: org["id"]
          })

          # Create membership
          Repo.insert!(%Membership{
            user_id: user.id,
            tenant_id: tenant.id,
            role: "admin"
          })

          created_count = created_count + 1
        existing_tenant ->
          # Ensure user has membership to existing tenant
          case Repo.get_by(Membership, user_id: user.id, tenant_id: existing_tenant.id) do
            nil ->
              Repo.insert!(%Membership{
                user_id: user.id,
                tenant_id: existing_tenant.id,
                role: "admin"
              })
              updated_count = updated_count + 1
            _ -> nil
          end
      end
    end

    message = cond do
      created_count > 0 and updated_count > 0 ->
        "Organizations synced successfully! Created #{created_count} new organization(s) and updated #{updated_count} membership(s)."
      created_count > 0 ->
        "Organizations synced successfully! Created #{created_count} new organization(s)."
      updated_count > 0 ->
        "Organizations synced successfully! Updated #{updated_count} membership(s)."
      true ->
        "Organizations synced successfully! All organizations were already up to date."
    end

    conn
    |> put_flash(:info, message)
    |> redirect(to: "/organizations/manage")
  end

  # Clean up old default organizations that shouldn't exist
  defp cleanup_default_organizations(user) do
    # Remove any memberships to default organizations for this user
    from(m in Membership,
      join: t in Tenant,
      on: m.tenant_id == t.id,
      where: m.user_id == ^user.id and t.clerk_org_id == "org_default"
    )
    |> Repo.delete_all()
  end

  # Fetch organizations from Clerk API
  # Production implementation with real Clerk API calls
  defp fetch_user_organizations_from_clerk(user, conn) do
    # This simulates what a real Clerk API call would return
    # In production, you would:
    # 1. Get the user's access token from session
    # 2. Make API call to https://api.clerk.dev/v1/organizations
    # 3. Parse the response and return organization data

    # For demo purposes, we'll return organizations based on the user's Clerk ID
    # This simulates different users having different organizations

    # PRODUCTION IMPLEMENTATION: Real Clerk API integration
    # Try to get access token, fallback to session token for development
    access_token = get_session(conn, :clerk_access_token) ||
                   get_session(conn, :clerk_session_token)

    IO.inspect(%{
      access_token: access_token != nil,
      clerk_access_token: get_session(conn, :clerk_access_token) != nil,
      clerk_session_token: get_session(conn, :clerk_session_token) != nil,
      actual_access_token: get_session(conn, :clerk_access_token),
      actual_session_token: get_session(conn, :clerk_session_token),
      clerk_secret: System.get_env("CLERK_SECRET_KEY") != nil
    }, label: "Token availability check")

    if access_token do
      try do
        # Make API call to Clerk organizations endpoint
        headers = [
          {"Authorization", "Bearer #{access_token}"},
          {"Content-Type", "application/json"}
        ]

        response = HTTPoison.get!("https://api.clerk.dev/v1/organizations", headers)

        case response.status_code do
          200 ->
            # Parse successful response
            organizations = Jason.decode!(response.body)["data"] || []

            # Transform Clerk organization format to our internal format
            Enum.map(organizations, fn org ->
              %{
                "id" => org["id"],
                "name" => org["name"] || org["slug"] || "Unnamed Organization"
              }
            end)

          _ ->
            # Log API error and return empty list
            IO.inspect("Clerk API error: #{response.status_code}", label: "Organization sync failed")
            []
        end
      rescue
        error ->
          # Log network/API errors and return empty list
          IO.inspect(error, label: "Clerk API request failed")
          []
      end
    else
      # Use Clerk secret key for server-side API calls
      clerk_secret = System.get_env("CLERK_SECRET_KEY")

      if clerk_secret do
        try do
          # Make authenticated API call using secret key
          headers = [
            {"Authorization", "Bearer #{clerk_secret}"},
            {"Content-Type", "application/json"}
          ]

          # Get organizations for the specific user
          response = HTTPoison.get!("https://api.clerk.dev/v1/users/#{user.clerk_id}/organization_memberships", headers)

          case response.status_code do
            200 ->
              # Parse successful response
              memberships = Jason.decode!(response.body) || []

              # Transform Clerk membership format to our internal format
              Enum.map(memberships, fn membership ->
                org = membership["organization"]
                %{
                  "id" => org["id"],
                  "name" => org["name"] || org["slug"] || "Unnamed Organization"
                }
              end)

            _ ->
              # Log API error and return empty list
              IO.inspect("Clerk API error: #{response.status_code}", label: "Organization fetch failed")
              []
          end
        rescue
          error ->
            # Log network/API errors and return empty list
            IO.inspect(error, label: "Clerk API request failed")
            []
        end
      else
        # No Clerk secret key configured
        IO.inspect("Clerk secret key not configured", label: "Organization sync failed")
        []
      end
    end
  end

  def create(conn, %{"organization" => %{"name" => name}}) do
    conn
    |> put_flash(:error, "Organizations must be created in Clerk first. Please create an organization in your Clerk dashboard, then sign in again.")
    |> redirect(to: "/organizations/manage")
  end

  def select(conn, %{"tenant_id" => tenant_id}) do
    user_id = get_session(conn, :user_id)

    # Verify user has access to this tenant
    case Repo.get_by(Membership, user_id: user_id, tenant_id: tenant_id) do
      nil ->
        conn
        |> put_flash(:error, "You don't have access to this organization")
        |> redirect(to: "/organizations/manage")

      _membership ->
        conn
        |> put_session(:tenant_id, tenant_id)
        |> redirect(to: "/#{tenant_id}/dashboard/default_fleet")
    end
  end
end
