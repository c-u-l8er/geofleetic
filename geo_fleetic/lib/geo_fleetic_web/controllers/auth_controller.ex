defmodule GeoFleeticWeb.AuthController do
  use GeoFleeticWeb, :controller
  import Ecto.Query
  alias GeoFleetic.{User, Membership, Tenant, Repo}

  def login(conn, _params) do
    # Redirect to Clerk's hosted sign-in page
    clerk_signin_url = "https://pro-mole-57.accounts.dev/sign-in?" <>
      URI.encode_query(%{
        redirect_url: "http://localhost:4000/auth/callback"
      })

    redirect(conn, external: clerk_signin_url)
  end

  def callback(conn, %{"__clerk_db_jwt" => jwt_token} = params) do
    # Decode and verify the Clerk JWT token
    case verify_clerk_jwt(jwt_token) do
      {:ok, claims} ->
        # Debug: Log JWT claims
        IO.inspect(claims, label: "JWT claims")

        # Try to get Clerk access token if code is provided
        access_token = if params["code"] do
          case exchange_clerk_code_for_token(params["code"]) do
            {:ok, token} -> token
            {:error, _} -> nil
          end
        else
          nil
        end

        # Store the JWT token as access token for API calls
        conn = conn
        |> put_session(:clerk_access_token, jwt_token)
        |> put_session(:clerk_session_token, jwt_token)

        # Extract user and organization info from JWT claims
        clerk_user = %{
          "id" => claims["sub"] || "user_#{:rand.uniform(1000)}",
          "email" => claims["email"] || "user@example.com",
          "first_name" => claims["given_name"] || claims["name"] || "Unknown",
          "last_name" => claims["family_name"] || "User"
        }

        # Try to get organization from JWT claims, fallback to default
        clerk_org = if claims["org_id"] do
          %{
            "id" => claims["org_id"],
            "name" => claims["org_name"] || claims["org_slug"] || "Organization #{claims["org_id"]}"
          }
        else
          %{
            "id" => "org_default",
            "name" => "Default Organization"
          }
        end

        # Find or create user
        user = find_or_create_user_from_clerk(clerk_user)

        # Sync all user's organizations from Clerk
        sync_user_organizations_from_clerk(user, conn)

        # If user has a Clerk organization in JWT, use it
        if claims["org_id"] do
          clerk_org = %{
            "id" => claims["org_id"],
            "name" => claims["org_name"] || claims["org_slug"] || "Organization #{claims["org_id"]}"
          }
          tenant = find_or_create_tenant_from_clerk(clerk_org, user)

          conn
          |> put_session(:user_id, user.id)
          |> put_session(:tenant_id, tenant.id)
          |> put_session(:clerk_session_token, jwt_token)
          |> redirect(to: "/#{tenant.id}/dashboard/default_fleet")
        else
          # No org in JWT, check if user has any organizations/tenants
          user_tenants = Repo.all(
            from t in Tenant,
            join: m in Membership,
            on: m.tenant_id == t.id,
            where: m.user_id == ^user.id
          )

          if Enum.empty?(user_tenants) do
            # User has no organizations, redirect to organization management
            conn
            |> put_session(:user_id, user.id)
            |> put_session(:clerk_session_token, jwt_token)
            |> redirect(to: "/organizations/manage")
          else
            # Use first available tenant
            tenant = List.first(user_tenants)

            conn
            |> put_session(:user_id, user.id)
            |> put_session(:tenant_id, tenant.id)
            |> put_session(:clerk_session_token, jwt_token)
            |> redirect(to: "/#{tenant.id}/dashboard/default_fleet")
          end
        end

      {:error, reason} ->
        # Log the error for debugging
        IO.inspect(reason, label: "JWT verification failed")

        # For demo purposes, create a fallback user if JWT fails
        # Use a consistent demo user ID for testing
        clerk_user = %{
          "id" => "demo_user_123",
          "email" => "demo@example.com",
          "first_name" => "Demo",
          "last_name" => "User"
        }

        user = find_or_create_user_from_clerk(clerk_user)

        # Check if demo user has any organizations
        user_tenants = Repo.all(
          from t in Tenant,
          join: m in Membership,
          on: m.tenant_id == t.id,
          where: m.user_id == ^user.id
        )

        if Enum.empty?(user_tenants) do
          # User has no organizations, redirect to organization management
          conn
          |> put_session(:user_id, user.id)
          |> put_flash(:info, "Logged in with demo account")
          |> redirect(to: "/organizations/manage")
        else
          # Use existing tenant
          tenant = List.first(user_tenants)

          conn
          |> put_session(:user_id, user.id)
          |> put_session(:tenant_id, tenant.id)
          |> put_flash(:info, "Logged in with demo account")
          |> redirect(to: "/#{tenant.id}/dashboard/default_fleet")
        end
    end
  end

  def callback(conn, _params) do
    # Handle any other callback scenarios
    conn
    |> put_flash(:error, "Invalid authentication callback")
    |> redirect(to: ~p"/auth/login")
  end


  def logout(conn, _params) do
    # Clear local session
    conn = clear_session(conn)

    # Since Clerk sign-out endpoint returns 404, just clear local session
    # and provide instructions for manual Clerk logout
    conn
    |> put_flash(:info, "Logged out of GeoFleetic. To sign out of Clerk, visit your profile page.")
    |> redirect(to: ~p"/")
  end

  def select_tenant(conn, %{"tenant_id" => tenant_id}) do
    user_id = get_session(conn, :user_id)
    pending_tenants = get_session(conn, :pending_tenants) || []

    if tenant_id in pending_tenants do
      conn
      |> put_session(:tenant_id, tenant_id)
      |> delete_session(:pending_tenants)
      |> redirect(to: "/#{tenant_id}/dashboard/default_fleet")
    else
      conn
      |> put_flash(:error, "Invalid tenant selection")
      |> redirect(to: ~p"/tenant/select")
    end
  end

  # Clerk API helpers
  defp verify_clerk_jwt(jwt_token) do
    # For development/demo purposes, we'll decode the JWT without full verification
    # In production, you should verify the JWT signature using Clerk's public key
    case decode_jwt(jwt_token) do
      {:ok, claims} ->
        {:ok, claims}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_jwt(token) do
    # Simple JWT decode (without signature verification for demo)
    # In production, use proper JWT library with signature verification
    try do
      parts = String.split(token, ".")
      if length(parts) == 3 do
        [header, payload, _signature] = parts
        decoded_payload = payload
                          |> String.replace("-", "+")
                          |> String.replace("_", "/")
                          |> Base.decode64!(padding: false)
                          |> Jason.decode!()
        {:ok, decoded_payload}
      else
        {:error, :invalid_jwt_format}
      end
    rescue
      error ->
        IO.inspect(error, label: "JWT decode error")
        {:error, :invalid_token}
    end
  end

  defp exchange_clerk_code_for_token(code) do
    # Exchange authorization code for access token
    clerk_secret = System.get_env("CLERK_SECRET_KEY")

    if clerk_secret do
      try do
        headers = [
          {"Content-Type", "application/x-www-form-urlencoded"}
        ]

        body = URI.encode_query(%{
          "client_id" => "your_clerk_client_id",  # You'd get this from Clerk dashboard
          "client_secret" => clerk_secret,
          "code" => code,
          "grant_type" => "authorization_code",
          "redirect_uri" => "http://localhost:4000/auth/callback"
        })

        response = HTTPoison.post!("https://api.clerk.dev/v1/oauth/token", body, headers)

        case response.status_code do
          200 ->
            token_data = Jason.decode!(response.body)
            {:ok, token_data["access_token"]}
          _ ->
            {:error, "Failed to exchange code for token"}
        end
      rescue
        error ->
          IO.inspect(error, label: "Token exchange failed")
          {:error, "Token exchange error"}
      end
    else
      {:error, "Clerk secret key not configured"}
    end
  end

  defp exchange_clerk_code(code) do
    # This would make an HTTP request to Clerk's API
    # For now, simulate the response
    {:ok, %{
      "user" => %{
        "id" => "user_#{:rand.uniform(1000)}",
        "email" => "user@example.com",
        "first_name" => "John",
        "last_name" => "Doe"
      },
      "organization" => %{
        "id" => "org_#{:rand.uniform(1000)}",
        "name" => "Demo Organization"
      },
      "token" => "session_token_#{:rand.uniform(10000)}"
    }}
  end

  defp revoke_clerk_session(_token) do
    # Would make HTTP request to revoke session
    :ok
  end

  defp find_or_create_user_from_clerk(clerk_user) do
    case Repo.get_by(User, clerk_id: clerk_user["id"]) do
      nil ->
        # Check if user exists with same email but different clerk_id
        case Repo.get_by(User, email: clerk_user["email"]) do
          nil ->
            # Create new user
            %User{}
            |> User.changeset(%{
              email: clerk_user["email"],
              clerk_id: clerk_user["id"],
              first_name: clerk_user["first_name"],
              last_name: clerk_user["last_name"]
            })
            |> Repo.insert!()

          existing_user ->
            # Update existing user with new clerk_id
            existing_user
            |> User.changeset(%{
              clerk_id: clerk_user["id"],
              first_name: clerk_user["first_name"],
              last_name: clerk_user["last_name"]
            })
            |> Repo.update!()
        end

      user ->
        user
    end
  end

  defp find_or_create_tenant_from_clerk(clerk_org, user) do
    # Try to find existing tenant for this organization
    case Repo.get_by(Tenant, clerk_org_id: clerk_org["id"]) do
      nil ->
        # Create new tenant for this organization
        tenant = Repo.insert!(%Tenant{
          name: clerk_org["name"],
          clerk_org_id: clerk_org["id"]
        })

        # Create membership for the user
        Repo.insert!(%Membership{
          user_id: user.id,
          tenant_id: tenant.id,
          role: "admin"  # First user in org is admin
        })

        tenant

      tenant ->
        # Ensure user has membership
        case Repo.get_by(Membership, user_id: user.id, tenant_id: tenant.id) do
          nil ->
            Repo.insert!(%Membership{
              user_id: user.id,
              tenant_id: tenant.id,
              role: "member"
            })
          _ -> nil
        end
        tenant
    end
  end

  defp clerk_configured? do
    System.get_env("NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY") != nil
  end

  defp sync_user_organizations_from_clerk(user, conn) do
    # In a real implementation, this would make an API call to Clerk
    # to fetch all organizations the user is a member of
    # For demo purposes, we'll sync organizations dynamically

    clerk_organizations = fetch_user_organizations_from_clerk(user, conn)

    for org <- clerk_organizations do
      # Check if tenant already exists
      case Repo.get_by(Tenant, clerk_org_id: org["id"]) do
        nil ->
          # Create new tenant
          tenant = Repo.insert!(%Tenant{
            name: org["name"],
            clerk_org_id: org["id"]
          })

          # Create membership if it doesn't exist
          case Repo.get_by(Membership, user_id: user.id, tenant_id: tenant.id) do
            nil ->
              Repo.insert!(%Membership{
                user_id: user.id,
                tenant_id: tenant.id,
                role: "admin"
              })
            _ -> nil
          end
        existing_tenant ->
          # Ensure user has membership
          case Repo.get_by(Membership, user_id: user.id, tenant_id: existing_tenant.id) do
            nil ->
              Repo.insert!(%Membership{
                user_id: user.id,
                tenant_id: existing_tenant.id,
                role: "member"
              })
            _ -> nil
          end
      end
    end
  end

  # Fetch organizations from Clerk API
  # Production implementation with real Clerk API calls
  defp fetch_user_organizations_from_clerk(user, conn) do
    # This simulates what a real Clerk API call would return
    # In production, you would:
    # 1. Get the user's access token from session
    # 2. Make API call to https://api.clerk.dev/v1/organizations
    # 3. Parse the response and return organization data

    # PRODUCTION IMPLEMENTATION: Real Clerk API integration
    # Try to get access token, fallback to session token for development
    access_token = get_session(conn, :clerk_access_token) ||
                   get_session(conn, :clerk_session_token)

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
end
