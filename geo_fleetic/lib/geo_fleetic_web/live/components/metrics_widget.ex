defmodule GeoFleeticWeb.MetricsWidget do
  @moduledoc """
  Performance metrics widget for real-time fleet analytics.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    # Set up periodic metrics updates
    if connected?(socket) do
      :timer.send_interval(30000, :update_metrics) # Update every 30 seconds
    end

    {:ok, assign(socket, %{
      metrics: load_initial_metrics(),
      time_range: "1h",
      chart_data: generate_chart_data()
    })}
  end

  @impl true
  def handle_event("change_time_range", %{"range" => range}, socket) do
    {:noreply, assign(socket, %{
      time_range: range,
      chart_data: generate_chart_data(range)
    })}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    {:noreply, assign(socket, %{
      metrics: load_current_metrics(),
      chart_data: generate_chart_data(socket.assigns.time_range)
    })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Performance Metrics</h3>
          <div class="flex space-x-2">
            <%= for {range, label} <- [{"1h", "1H"}, {"24h", "24H"}, {"7d", "7D"}] do %>
              <button
                phx-click="change_time_range"
                phx-value-range={range}
                class={"px-3 py-1 text-sm rounded-md " <>
                       if(@time_range == range, do: "bg-blue-100 text-blue-800", else: "text-gray-600 hover:bg-gray-100")}
              >
                <%= label %>
              </button>
            <% end %>
          </div>
        </div>

        <!-- Key Metrics Grid -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600"><%= @metrics.active_vehicles %></div>
            <div class="text-sm text-gray-500">Active Vehicles</div>
            <div class="text-xs text-green-600 mt-1">+<%= @metrics.vehicle_change %>%</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-green-600"><%= format_duration(@metrics.avg_response_time) %></div>
            <div class="text-sm text-gray-500">Avg Response</div>
            <div class="text-xs text-red-600 mt-1">-<%= @metrics.response_improvement %>%</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-yellow-600"><%= @metrics.on_time_percentage %>%</div>
            <div class="text-sm text-gray-500">On-Time Rate</div>
            <div class="text-xs text-green-600 mt-1">+<%= @metrics.on_time_trend %>%</div>
          </div>

          <div class="text-center">
            <div class="text-2xl font-bold text-red-600"><%= @metrics.active_alerts %></div>
            <div class="text-sm text-gray-500">Active Alerts</div>
            <div class="text-xs text-red-600 mt-1">+<%= @metrics.alert_trend %>%</div>
          </div>
        </div>

        <!-- Performance Chart -->
        <div class="mb-6">
          <h4 class="text-md font-medium text-gray-900 mb-3">Response Time Trend</h4>
          <div class="bg-gray-50 rounded-lg p-4 h-48 flex items-center justify-center">
            <div class="text-center">
              <div class="text-4xl mb-2">📈</div>
              <p class="text-gray-600">Performance Chart</p>
              <p class="text-sm text-gray-400">Real-time metrics visualization</p>
            </div>
          </div>
        </div>

        <!-- Detailed Metrics -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Fleet Utilization -->
          <div>
            <h4 class="text-md font-medium text-gray-900 mb-3">Fleet Utilization</h4>
            <div class="space-y-3">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">Vehicle Usage</span>
                <span class="text-sm font-medium"><%= @metrics.fleet_utilization %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style={"width: #{@metrics.fleet_utilization}%"}></div>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">Route Efficiency</span>
                <span class="text-sm font-medium"><%= @metrics.route_efficiency %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-green-600 h-2 rounded-full" style={"width: #{@metrics.route_efficiency}%"}></div>
              </div>
            </div>
          </div>

          <!-- System Health -->
          <div>
            <h4 class="text-md font-medium text-gray-900 mb-3">System Health</h4>
            <div class="space-y-3">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">WebSocket Connections</span>
                <span class="text-sm font-medium text-green-600"><%= @metrics.websocket_connections %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">Database Response</span>
                <span class="text-sm font-medium text-green-600"><%= format_duration(@metrics.db_response_time) %></span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">Memory Usage</span>
                <span class="text-sm font-medium"><%= @metrics.memory_usage %>%</span>
              </div>

              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">CPU Usage</span>
                <span class="text-sm font-medium"><%= @metrics.cpu_usage %>%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp load_initial_metrics do
    %{
      active_vehicles: 42,
      vehicle_change: 8,
      avg_response_time: 180, # seconds
      response_improvement: 12,
      on_time_percentage: 94,
      on_time_trend: 2,
      active_alerts: 3,
      alert_trend: 1,
      fleet_utilization: 78,
      route_efficiency: 85,
      websocket_connections: 156,
      db_response_time: 45, # ms
      memory_usage: 67,
      cpu_usage: 34
    }
  end

  defp load_current_metrics do
    # TODO: Load real metrics from monitoring system
    load_initial_metrics()
  end

  defp generate_chart_data(time_range \\ "1h") do
    # TODO: Generate real chart data based on time range
    %{
      labels: ["00:00", "04:00", "08:00", "12:00", "16:00", "20:00"],
      datasets: [
        %{
          label: "Response Time",
          data: [180, 165, 150, 140, 155, 170],
          borderColor: "rgb(59, 130, 246)",
          backgroundColor: "rgba(59, 130, 246, 0.1)"
        }
      ]
    }
  end

  defp format_duration(seconds) when is_integer(seconds) do
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m"
    end
  end

  defp format_duration(milliseconds) when is_integer(milliseconds) do
    "#{milliseconds}ms"
  end
end
