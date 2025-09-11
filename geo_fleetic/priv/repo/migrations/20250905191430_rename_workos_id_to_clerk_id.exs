defmodule GeoFleetic.Repo.Migrations.RenameWorkosIdToClerkId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :workos_id
    end
  end
end
