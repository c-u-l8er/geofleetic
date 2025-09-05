defmodule GeoFleeticWeb.DispatchController do
  use GeoFleeticWeb, :controller
  use Stellarmorphism

  @moduledoc """
  API controller for handling dispatch requests.
  """

  def create(conn, params) do
    # Create dispatch request based on type
    dispatch_request = case params do
      %{"type" => "emergency"} ->
        core EmergencyRequest,
          location: %Geo.Point{
            coordinates: {params["lng"], params["lat"]},
            srid: 4326
          },
          emergency_type: params["emergency_type"] || "general",
          severity: params["severity"] || 3,
          reported_by: params["reported_by"] || "system",
          additional_info: params["additional_info"]

      %{"type" => "service"} ->
        core ServiceRequest,
          location: %Geo.Point{
            coordinates: {params["lng"], params["lat"]},
            srid: 4326
          },
          priority: params["priority"] || :normal,
          service_type: params["service_type"] || "pickup",
          estimated_duration: params["estimated_duration"] || 30,
          special_requirements: params["special_requirements"] || [],
          customer_id: params["customer_id"]

      _ ->
        core ServiceRequest,
          location: %Geo.Point{
            coordinates: {params["lng"], params["lat"]},
            srid: 4326
          },
          priority: :normal,
          service_type: "general",
          estimated_duration: 30,
          special_requirements: [],
          customer_id: nil
    end

    # Process dispatch request
    case GeoFleetic.DispatchEngine.process_dispatch_request(dispatch_request) do
      {:ok, assignment} ->
        # Log successful dispatch
        GeoFleetic.Logger.log_dispatch_event("request_created", assignment.request_id, assignment.vehicle_id,
          priority_score: assignment.assignment_score,
          estimated_arrival: assignment.estimated_arrival
        )

        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          assignment: %{
            vehicle_id: assignment.vehicle_id,
            estimated_arrival: assignment.estimated_arrival,
            assignment_score: assignment.assignment_score
          }
        })

      {:error, reason} ->
        # Log failed dispatch
        GeoFleetic.Logger.log_error("dispatch_failed", reason, %{params: params})

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Unable to assign vehicle: #{reason}"})
    end
  end
end
