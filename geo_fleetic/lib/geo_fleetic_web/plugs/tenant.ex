defmodule GeoFleeticWeb.Plugs.Tenant do
  import Plug.Conn
  alias GeoFleetic.{Tenant, Membership, Repo}

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant_id = conn.params["tenant_id"] || get_session(conn, :current_tenant_id)
    user = conn.assigns[:current_user]

    case tenant_id && Repo.get(Tenant, tenant_id) do
      nil ->
        conn
        |> put_status(404)
        |> Phoenix.Controller.json(%{error: "Tenant not found"})
        |> halt()

      tenant ->
        # Verify user has access to this tenant
        case Repo.get_by(Membership, user_id: user.id, tenant_id: tenant.id) do
          nil ->
            conn
            |> put_status(403)
            |> Phoenix.Controller.json(%{error: "Access denied"})
            |> halt()

          _membership ->
            conn
            |> assign(:current_tenant, tenant)
            |> put_session(:current_tenant_id, tenant.id)
        end
    end
  end
end
