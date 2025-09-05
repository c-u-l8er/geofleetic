defmodule GeoFleetic.SmartGeofencing do
  @moduledoc """
  Advanced geofencing system with multi-layered geofence types.

  Uses Stellarmorphism stellar types for type-safe geofence operations.
  """

  use Stellarmorphism

  # Import the core fleet types
  import Stellarmorphism.FleetTypes

  @doc """
  Advanced geofence types with conditions and behaviors.
  """
  defstar AdvancedGeofence do
    derive [Ecto.Schema, PostGIS.Geometry]

    layers do
      core StaticGeofence,
        boundary :: Geometry.Polygon.t(),
        geofence_type :: atom(),
        hysteresis_buffer :: float(),
        dwell_time_seconds :: integer()

      core DynamicGeofence,
        center_vehicle_id :: String.t(),
        radius_meters :: float(),
        follow_distance :: boolean(),
        update_interval_seconds :: integer()

      core TemporalGeofence,
        boundary :: Geometry.Polygon.t(),
        active_schedule :: map(),  # Time schedule data
        timezone :: String.t()

      core ConditionalGeofence,
        boundary :: Geometry.Polygon.t(),
        conditions :: list(),  # List of conditions
        logical_operator :: atom()

      core PredictiveGeofence,
        ml_model_id :: String.t(),
        prediction_window_minutes :: integer(),
        confidence_threshold :: float(),
        trigger_conditions :: map()
    end
  end

  @doc """
  Geofence condition types for conditional geofences.
  """
  defstar GeofenceCondition do
    layers do
      core SpeedCondition,
        operator :: atom(),  # :gt, :lt, :eq, :gte, :lte
        value :: float()

      core TimeCondition,
        start_time :: Time.t(),
        end_time :: Time.t()

      core VehicleTypeCondition,
        allowed_types :: [atom()]

      core BatteryCondition,
        operator :: atom(),
        value :: integer()

      core CustomCondition,
        expression :: String.t(),  # Custom Elixir expression
        variables :: map()
    end
  end

  @doc """
  Time schedule for temporal geofences.
  """
  defstar TimeSchedule do
    layers do
      core DailySchedule,
        start_time :: Time.t(),
        end_time :: Time.t(),
        days_of_week :: [integer()]  # 1-7 (Monday-Sunday)

      core WeeklySchedule,
        schedules :: [asteroid(DailySchedule)]

      core HolidaySchedule,
        holiday_dates :: [Date.t()],
        exception_dates :: [Date.t()]
    end
  end

  @doc """
  Temporal geofence evaluator.
  """
  defstar TemporalEvaluator do
    layers do
      core TimeBasedEvaluator,
        schedule :: asteroid(TimeSchedule),
        timezone :: String.t()

      core SeasonalEvaluator,
        season_start :: Date.t(),
        season_end :: Date.t(),
        active_hours :: {Time.t(), Time.t()}
    end
  end

  @doc """
  Predictive geofence evaluator using ML models.
  """
  defstar PredictiveEvaluator do
    layers do
      core RoutePrediction,
        historical_routes :: list(),
        traffic_patterns :: map(),
        confidence_threshold :: float()

      core BehaviorPrediction,
        vehicle_history :: list(),
        pattern_recognition :: map(),
        risk_assessment :: float()
    end
  end

  @doc """
  Geofence type enumeration.
  """
  defstar GeofenceType do
    layers do
      core ZoneGeofence
      core RestrictedGeofence
      core SpeedZoneGeofence
      core ParkingGeofence
      core LoadingGeofence
      core ServiceGeofence
    end
  end

  @doc """
  Geofence breach event types.
  """
  defstar GeofenceBreach do
    layers do
      core EntryBreach,
        vehicle_id :: String.t(),
        geofence_id :: String.t(),
        entry_time :: DateTime.t(),
        location :: Geo.Point.t(),
        vehicle_speed :: float(),
        breach_severity :: atom()

      core ExitBreach,
        vehicle_id :: String.t(),
        geofence_id :: String.t(),
        exit_time :: DateTime.t(),
        location :: Geo.Point.t(),
        dwell_duration :: integer(),
        exit_speed :: float()

      core DwellBreach,
        vehicle_id :: String.t(),
        geofence_id :: String.t(),
        dwell_duration :: integer(),
        max_allowed_dwell :: integer(),
        location :: Geo.Point.t()

      core SpeedBreach,
        vehicle_id :: String.t(),
        geofence_id :: String.t(),
        actual_speed :: float(),
        speed_limit :: float(),
        location :: Geo.Point.t(),
        breach_duration :: integer()
    end
  end
end
