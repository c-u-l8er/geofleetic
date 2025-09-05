defmodule GeoFleetic.RealtimeProcessor do
  use GenServer
  use Stellarmorphism

  @moduledoc """
  High-throughput real-time location update processing.

  Features:
  - Batch processing every 100ms
  - Parallel geofence violation checking
  - Event broadcasting to subscribers
  - Memory-efficient bulk database operations
  """

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    # Start location update batch processor
    :timer.send_interval(100, :process_batch)

    {:ok, %{
      pending_updates: [],
      batch_size: 1000,
      last_processed: System.monotonic_time(:millisecond)
    }}
  end

  def process_location_update(location_update) do
    GenServer.cast(__MODULE__, {:location_update, location_update})
  end

  def handle_cast({:location_update, update}, state) do
    {:noreply, %{state | pending_updates: [update | state.pending_updates]}}
  end

  def handle_info(:process_batch, state) do
    if length(state.pending_updates) > 0 do
      # Process batch of location updates
      updates = Enum.reverse(state.pending_updates)
      process_location_batch(updates)

      {:noreply, %{
        state |
        pending_updates: [],
        last_processed: System.monotonic_time(:millisecond)
      }}
    else
      {:noreply, state}
    end
  end

  # Batch Location Processing
  defp process_location_batch(updates) do
    # Convert updates to database format using stellar pattern matching
    location_data = Enum.map(updates, fn update ->
      fission GeoFleetic.FleetEvent, update do
        core VehicleLocationUpdate,
          vehicle_id: id,
          location: loc,
          speed: speed,
          heading: heading,
          timestamp: ts ->

          %{
            vehicle_id: id,
            location: loc,
            speed: speed,
            heading: heading,
            updated_at: ts
          }
      end
    end)

    # Bulk upsert to database for performance
    GeoFleetic.Repo.insert_all(
      GeoFleetic.VehicleLocation,
      location_data,
      conflict_target: [:vehicle_id],
      on_conflict: {:replace, [:location, :speed, :heading, :updated_at]}
    )

    # Process geofence checks in parallel with optimized batching
    updates
    |> Task.async_stream(&check_geofence_violations/1,
        max_concurrency: System.schedulers_online() * 2,
        timeout: 5000,
        on_timeout: :kill_task
      )
    |> Stream.run()

    # Broadcast location updates to subscribers
    Enum.each(updates, &broadcast_location_update/1)
  end

  # Parallel Geofence Checking with Enhanced Performance
  defp check_geofence_violations(location_update) do
    try do
      fission GeoFleetic.FleetEvent, location_update do
        core VehicleLocationUpdate, vehicle_id: vehicle_id, location: new_location ->
          # Batch geofence queries for better performance
          {current_geofences, geofence_details} = get_geofence_data_batch(new_location)
          previous_geofences = GeoFleetic.VehicleState.get_previous_geofences(vehicle_id)

          # Detect entries and exits with hysteresis
          {entries, exits} = detect_geofence_transitions(
            current_geofences,
            previous_geofences,
            vehicle_id,
            new_location
          )

          # Process breach events in parallel
          process_breach_events_parallel(entries, :entry, vehicle_id, new_location)
          process_breach_events_parallel(exits, :exit, vehicle_id, new_location)

          # Update vehicle's geofence state with hysteresis tracking
          GeoFleetic.VehicleState.update_geofences(vehicle_id, current_geofences)
      end
    catch
      kind, reason ->
        # Log error but don't crash the processing pipeline
        Logger.error("Geofence violation check failed: #{inspect({kind, reason})}")
        :ok
    end
  end

  # Batch geofence data retrieval for performance
  defp get_geofence_data_batch(location) do
    # TODO: Implement batch geofence query
    # For now, return mock data
    {MapSet.new(["geofence_1", "geofence_2"]), %{}}
  end

  # Detect geofence transitions with hysteresis
  defp detect_geofence_transitions(current_geofences, previous_geofences, vehicle_id, location) do
    entries = MapSet.difference(current_geofences, previous_geofences)
    exits = MapSet.difference(previous_geofences, current_geofences)

    # Apply hysteresis filtering to prevent rapid transitions
    filtered_entries = filter_transitions_with_hysteresis(entries, vehicle_id, :entry)
    filtered_exits = filter_transitions_with_hysteresis(exits, vehicle_id, :exit)

    {filtered_entries, filtered_exits}
  end

  # Filter transitions using hysteresis to prevent rapid enter/exit events
  defp filter_transitions_with_hysteresis(transitions, vehicle_id, transition_type) do
    Enum.filter(transitions, fn geofence_id ->
      # Check if enough time has passed since last transition
      last_transition = get_last_transition_time(vehicle_id, geofence_id, transition_type)
      time_since_last = DateTime.diff(DateTime.utc_now(), last_transition, :millisecond)

      # Minimum 5 seconds between same type transitions for same geofence
      time_since_last > 5000
    end)
  end

  # Process breach events in parallel
  defp process_breach_events_parallel(geofence_ids, breach_type, vehicle_id, location) do
    Enum.each(geofence_ids, fn geofence_id ->
      Task.async(fn ->
        breach_event = core GeofenceBreach,
          vehicle_id: vehicle_id,
          geofence_id: geofence_id,
          breach_type: breach_type,
          location: location,
          timestamp: DateTime.utc_now()

        GeoFleetic.EventProcessor.process_event(breach_event)
        update_last_transition_time(vehicle_id, geofence_id, breach_type)
      end)
    end)
  end

  # Cache last transition times for hysteresis
  defp get_last_transition_time(vehicle_id, geofence_id, transition_type) do
    # TODO: Implement caching for transition times
    # For now, return old timestamp
    DateTime.add(DateTime.utc_now(), -10, :second)
  end

  defp update_last_transition_time(vehicle_id, geofence_id, transition_type) do
    # TODO: Update cached transition time
    :ok
  end

  # Broadcasting
  defp broadcast_location_update(location_update) do
    fission GeoFleetic.FleetEvent, location_update do
      core VehicleLocationUpdate, vehicle_id: vehicle_id, location: location ->
        # Broadcast to fleet subscribers
        Phoenix.PubSub.broadcast(
          GeoFleetic.PubSub,
          "vehicle_locations:#{get_fleet_id(vehicle_id)}",
          {:location_update, location_update}
        )

        # Broadcast to specific vehicle subscribers
        Phoenix.PubSub.broadcast(
          GeoFleetic.PubSub,
          "vehicle:#{vehicle_id}",
          {:location_update, location_update}
        )
    end
  end

  # Helper functions
  defp get_fleet_id(vehicle_id) do
    # TODO: Implement fleet lookup from vehicle_id
    "default_fleet"
  end
end
