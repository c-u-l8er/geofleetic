defmodule GeoFleetic.PostGISTypes do
  @moduledoc """
  Custom Postgrex types module to handle PostGIS geometry types
  """
  @behaviour Postgrex.Types

  # Handle geometry type by treating it as binary data
  def decode(%Postgrex.TypeInfo{type: "geometry"}, <<_size::32, wkb::binary>>, _types) do
    wkb
  end

  # Fallback to default types for everything else
  def decode(type_info, data, types) do
    Postgrex.DefaultTypes.decode(type_info, data, types)
  end

  # Use default encoding for all types
  def encode(type_info, data, types) do
    Postgrex.DefaultTypes.encode(type_info, data, types)
  end

  # Delegate find to default types
  def find(type_info, types) do
    Postgrex.DefaultTypes.find(type_info, types)
  end
end
