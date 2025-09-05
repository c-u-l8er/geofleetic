defmodule GeoFleetic.Repo do
  use Ecto.Repo,
    otp_app: :geo_fleetic,
    adapter: Ecto.Adapters.Postgres
end
