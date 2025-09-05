defmodule GeoFleetic.EventProcessor do
  @moduledoc """
  Processes fleet events and broadcasts them to subscribers.
  """

  def process_event(event) do
    # Broadcast event to appropriate channels
    broadcast_event(event)
  end

  defp broadcast_event(event) do
    # Extract event type and broadcast accordingly
    case event do
      %{__struct__: _, geofence_id: geofence_id} ->
        Phoenix.PubSub.broadcast(
          GeoFleetic.PubSub,
          "geofence:#{geofence_id}",
          {:geofence_breach, event}
        )

        Phoenix.PubSub.broadcast(
          GeoFleetic.PubSub,
          "geofence_alerts:#{get_fleet_id_from_geofence(geofence_id)}",
          {:geofence_breach, event}
        )

      _ ->
        # Handle other event types
        :ok
    end
  end

  defp get_fleet_id_from_geofence(_geofence_id) do
    # TODO: Implement fleet lookup from geofence_id
    "default_fleet"
  end
end
