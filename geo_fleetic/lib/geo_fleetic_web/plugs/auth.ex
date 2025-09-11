defmodule GeoFleeticWeb.Plugs.Auth do
  import Plug.Conn
  alias GeoFleetic.{User, Repo}

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    case user_id && Repo.get(User, user_id) do
      nil ->
        conn
        |> Phoenix.Controller.redirect(to: "/auth/login")
        |> halt()

      user ->
        assign(conn, :current_user, user)
    end
  end
end
