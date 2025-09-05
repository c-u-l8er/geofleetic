defmodule GeoFleetic.Logger do
  @moduledoc """
  Comprehensive logging system for GeoFleetic.

  Provides structured logging for fleet operations, performance monitoring,
  and error tracking.
  """

  require Logger

  @doc """
  Log fleet events with structured data.
  """
  def log_fleet_event(event_type, data, metadata \\ %{}) do
    log_data = %{
      event_type: event_type,
      timestamp: DateTime.utc_now(),
      data: data,
      metadata: metadata
    }

    Logger.info("Fleet Event: #{event_type}", log_data: log_data)
  end

  @doc """
  Log vehicle location updates.
  """
  def log_vehicle_location(vehicle_id, location, metadata \\ %{}) do
    log_data = %{
      vehicle_id: vehicle_id,
      location: location,
      speed: metadata[:speed],
      heading: metadata[:heading],
      accuracy: metadata[:accuracy],
      timestamp: DateTime.utc_now()
    }

    Logger.debug("Vehicle Location Update", log_data: log_data)
  end

  @doc """
  Log geofence events.
  """
  def log_geofence_event(event_type, vehicle_id, geofence_id, location, metadata \\ %{}) do
    log_data = %{
      event_type: event_type,
      vehicle_id: vehicle_id,
      geofence_id: geofence_id,
      location: location,
      breach_type: metadata[:breach_type],
      dwell_time: metadata[:dwell_time],
      timestamp: DateTime.utc_now()
    }

    Logger.info("Geofence Event: #{event_type}", log_data: log_data)
  end

  @doc """
  Log dispatch events.
  """
  def log_dispatch_event(event_type, request_id, vehicle_id, metadata \\ %{}) do
    log_data = %{
      event_type: event_type,
      request_id: request_id,
      vehicle_id: vehicle_id,
      priority_score: metadata[:priority_score],
      estimated_arrival: metadata[:estimated_arrival],
      assignment_score: metadata[:assignment_score],
      processing_time_ms: metadata[:processing_time_ms],
      timestamp: DateTime.utc_now()
    }

    Logger.info("Dispatch Event: #{event_type}", log_data: log_data)
  end

  @doc """
  Log performance metrics.
  """
  def log_performance_metric(metric_name, value, tags \\ %{}) do
    log_data = %{
      metric_name: metric_name,
      value: value,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    Logger.info("Performance Metric: #{metric_name}=#{value}", log_data: log_data)
  end

  @doc """
  Log errors with context.
  """
  def log_error(error_type, error, context \\ %{}) do
    stacktrace = try do
      throw(:get_stacktrace)
    catch
      _ -> __STACKTRACE__
    end

    log_data = %{
      error_type: error_type,
      error: inspect(error),
      context: context,
      stacktrace: stacktrace,
      timestamp: DateTime.utc_now()
    }

    Logger.error("Error: #{error_type}", log_data: log_data)
  end

  @doc """
  Log WebSocket connection events.
  """
  def log_websocket_event(event_type, socket_id, metadata \\ %{}) do
    log_data = %{
      event_type: event_type,
      socket_id: socket_id,
      topic: metadata[:topic],
      user_id: metadata[:user_id],
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      timestamp: DateTime.utc_now()
    }

    Logger.info("WebSocket Event: #{event_type}", log_data: log_data)
  end

  @doc """
  Log database query performance.
  """
  def log_database_query(query_type, table, duration_ms, metadata \\ %{}) do
    log_data = %{
      query_type: query_type,
      table: table,
      duration_ms: duration_ms,
      row_count: metadata[:row_count],
      query: metadata[:query],
      timestamp: DateTime.utc_now()
    }

    if duration_ms > 1000 do
      Logger.warning("Slow Database Query: #{query_type} on #{table} took #{duration_ms}ms", log_data: log_data)
    else
      Logger.debug("Database Query: #{query_type} on #{table}", log_data: log_data)
    end
  end

  @doc """
  Log system health metrics.
  """
  def log_system_health(metric_type, value, status, metadata \\ %{}) do
    log_data = %{
      metric_type: metric_type,
      value: value,
      status: status,
      threshold: metadata[:threshold],
      timestamp: DateTime.utc_now()
    }

    case status do
      :healthy -> Logger.info("System Health: #{metric_type} = #{value}", log_data: log_data)
      :warning -> Logger.warning("System Health Warning: #{metric_type} = #{value}", log_data: log_data)
      :critical -> Logger.error("System Health Critical: #{metric_type} = #{value}", log_data: log_data)
    end
  end

  @doc """
  Log security events.
  """
  def log_security_event(event_type, user_id, resource, action, metadata \\ %{}) do
    log_data = %{
      event_type: event_type,
      user_id: user_id,
      resource: resource,
      action: action,
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      success: metadata[:success] || false,
      timestamp: DateTime.utc_now()
    }

    Logger.warning("Security Event: #{event_type}", log_data: log_data)
  end

  @doc """
  Log business metrics.
  """
  def log_business_metric(metric_name, value, period, metadata \\ %{}) do
    log_data = %{
      metric_name: metric_name,
      value: value,
      period: period,
      fleet_id: metadata[:fleet_id],
      region: metadata[:region],
      timestamp: DateTime.utc_now()
    }

    Logger.info("Business Metric: #{metric_name} = #{value} (#{period})", log_data: log_data)
  end

  @doc """
  Create a structured log entry with all context.
  """
  def log_structured(level, message, context) do
    enriched_context = Map.merge(context, %{
      timestamp: DateTime.utc_now(),
      hostname: get_hostname(),
      pid: inspect(self()),
      module: get_calling_module()
    })

    Logger.log(level, message, log_data: enriched_context)
  end

  # Helper functions

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      _ -> "unknown"
    end
  end

  defp get_calling_module do
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, stacktrace} ->
        case Enum.find(stacktrace, fn {mod, _fun, _arity, _loc} ->
          mod != __MODULE__ and mod != Logger
        end) do
          {mod, _fun, _arity, _loc} -> to_string(mod)
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end
end
