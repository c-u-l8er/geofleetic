defmodule GeoFleeticWeb.TenantController do
  use GeoFleeticWeb, :controller
  import Ecto.Query
  alias GeoFleetic.{Tenant, Repo}

  def select(conn, _params) do
    _user_id = get_session(conn, :user_id)
    pending_tenant_ids = get_session(conn, :pending_tenants) || []

    tenants = Repo.all(
      from t in Tenant,
      where: t.id in ^pending_tenant_ids
    )

    render(conn, :select, tenants: tenants)
  end
end
