defmodule GeoFleeticWeb.AlertMonitor do
  @moduledoc """
  Real-time alert monitoring and management system.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "geofence_alerts:#{socket.assigns.fleet_id}")
      Phoenix.PubSub.subscribe(GeoFleetic.PubSub, "emergency_alerts:#{socket.assigns.fleet_id}")
    end

    {:ok, assign(socket, %{
      alerts: load_recent_alerts(),
      filter_severity: "all",
      show_acknowledged: false,
      auto_refresh: true
    })}
  end

  @impl true
  def handle_event("acknowledge_alert", %{"alert_id" => alert_id}, socket) do
    # Acknowledge the alert
    updated_alerts = Enum.map(socket.assigns.alerts, fn alert ->
      if alert.id == alert_id do
        %{alert | acknowledged: true, acknowledged_at: DateTime.utc_now()}
      else
        alert
      end
    end)

    {:noreply, assign(socket, alerts: updated_alerts)}
  end

  @impl true
  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    {:noreply, assign(socket, filter_severity: severity)}
  end

  @impl true
  def handle_event("toggle_acknowledged", _params, socket) do
    {:noreply, assign(socket, show_acknowledged: !socket.assigns.show_acknowledged)}
  end

  @impl true
  def handle_event("clear_resolved", _params, socket) do
    # Remove resolved alerts older than 1 hour
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600)
    filtered_alerts = Enum.filter(socket.assigns.alerts, fn alert ->
      not (alert.resolved and DateTime.compare(alert.resolved_at || DateTime.utc_now(), cutoff_time) == :lt)
    end)

    {:noreply, assign(socket, alerts: filtered_alerts)}
  end

  @impl true
  def handle_info({:geofence_alert, alert_data}, socket) do
    new_alert = %{
      id: generate_alert_id(),
      type: :geofence_breach,
      severity: get_breach_severity(alert_data.type),
      title: "Geofence Breach",
      message: "#{alert_data.vehicle_id} #{alert_data.type}d geofence #{alert_data.geofence_id}",
      vehicle_id: alert_data.vehicle_id,
      geofence_id: alert_data.geofence_id,
      location: alert_data.location,
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      resolved: false
    }

    updated_alerts = [new_alert | socket.assigns.alerts] |> Enum.take(100) # Keep last 100 alerts

    {:noreply, assign(socket, alerts: updated_alerts)}
  end

  @impl true
  def handle_info({:emergency_alert, alert_data}, socket) do
    new_alert = %{
      id: generate_alert_id(),
      type: :emergency,
      severity: :critical,
      title: "Emergency Alert",
      message: alert_data.message,
      vehicle_id: alert_data.vehicle_id,
      location: alert_data.location,
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      resolved: false
    }

    updated_alerts = [new_alert | socket.assigns.alerts] |> Enum.take(100)

    {:noreply, assign(socket, alerts: updated_alerts)}
  end

  @impl true
  def render(assigns) do
    filtered_alerts = filter_alerts(assigns.alerts, assigns.filter_severity, assigns.show_acknowledged)
    alert_counts = count_alerts_by_severity(assigns.alerts)

    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Alert Monitor</h3>
          <div class="flex items-center space-x-2">
            <button
              phx-click="clear_resolved"
              class="px-3 py-1 text-sm text-gray-600 hover:bg-gray-100 rounded-md"
            >
              Clear Resolved
            </button>
            <label class="flex items-center">
              <input
                type="checkbox"
                phx-click="toggle_acknowledged"
                checked={@show_acknowledged}
                class="mr-2"
              />
              <span class="text-sm text-gray-600">Show Acknowledged</span>
            </label>
          </div>
        </div>

        <!-- Alert Summary -->
        <div class="grid grid-cols-4 gap-4 mb-6">
          <%= for {severity, count, color} <- [
            {"critical", alert_counts.critical, "red"},
            {"high", alert_counts.high, "orange"},
            {"medium", alert_counts.medium, "yellow"},
            {"low", alert_counts.low, "blue"}
          ] do %>
            <button
              phx-click="filter_severity"
              phx-value-severity={severity}
              class={"text-center p-3 rounded-lg border-2 " <>
                     if(@filter_severity == severity, do: "border-#{color}-500 bg-#{color}-50", else: "border-gray-200 hover:border-gray-300")}
            >
              <div class={"text-2xl font-bold text-#{color}-600"}><%= count %></div>
              <div class="text-sm text-gray-600 capitalize"><%= severity %></div>
            </button>
          <% end %>
        </div>

        <!-- Alert List -->
        <div class="space-y-3 max-h-96 overflow-y-auto">
          <%= if Enum.empty?(filtered_alerts) do %>
            <div class="text-center py-8">
              <div class="text-4xl mb-4">✅</div>
              <p class="text-gray-500">No active alerts</p>
              <p class="text-sm text-gray-400 mt-2">All systems operating normally</p>
            </div>
          <% else %>
            <%= for alert <- filtered_alerts do %>
              <div class={"border-l-4 p-4 rounded-r-lg " <>
                         get_alert_styling(alert.severity, alert.acknowledged)}>
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-3">
                    <div class={"w-3 h-3 rounded-full " <> get_severity_color(alert.severity)}></div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-900"><%= alert.title %></h4>
                      <p class="text-sm text-gray-600"><%= alert.message %></p>
                      <div class="flex items-center space-x-4 mt-1 text-xs text-gray-500">
                        <span>🕒 <%= format_timestamp(alert.timestamp) %></span>
                        <span>🚗 <%= alert.vehicle_id %></span>
                        <%= if alert.geofence_id do %>
                          <span>🏛️ <%= alert.geofence_id %></span>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center space-x-2">
                    <%= if not alert.acknowledged do %>
                      <button
                        phx-click="acknowledge_alert"
                        phx-value-alert_id={alert.id}
                        class="px-3 py-1 text-sm bg-blue-100 text-blue-800 rounded-md hover:bg-blue-200"
                      >
                        Acknowledge
                      </button>
                    <% else %>
                      <span class="px-3 py-1 text-sm bg-green-100 text-green-800 rounded-md">
                        ✓ Acknowledged
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp load_recent_alerts do
    # TODO: Load recent alerts from database
    []
  end

  defp generate_alert_id do
    "alert_#{:erlang.system_time(:millisecond)}"
  end

  defp get_breach_severity(breach_type) do
    case breach_type do
      :exit -> :high
      :entry -> :medium
      _ -> :low
    end
  end

  defp filter_alerts(alerts, severity_filter, show_acknowledged) do
    alerts
    |> Enum.filter(fn alert ->
      (severity_filter == "all" or Atom.to_string(alert.severity) == severity_filter) and
      (show_acknowledged or not alert.acknowledged)
    end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  defp count_alerts_by_severity(alerts) do
    Enum.reduce(alerts, %{critical: 0, high: 0, medium: 0, low: 0}, fn alert, acc ->
      if not alert.acknowledged do
        Map.update(acc, alert.severity, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  defp get_alert_styling(severity, acknowledged) do
    base_class = if acknowledged, do: "bg-gray-50 border-gray-300", else: "bg-white border-gray-200"

    severity_class = case severity do
      :critical -> "border-red-500"
      :high -> "border-orange-500"
      :medium -> "border-yellow-500"
      :low -> "border-blue-500"
    end

    "#{base_class} #{severity_class}"
  end

  defp get_severity_color(severity) do
    case severity do
      :critical -> "bg-red-500"
      :high -> "bg-orange-500"
      :medium -> "bg-yellow-500"
      :low -> "bg-blue-500"
    end
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
