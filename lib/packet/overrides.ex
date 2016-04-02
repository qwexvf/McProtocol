defmodule McProtocol.Packet.Overrides do
  @moduledoc false

  def packet_name("RelEntityMove"), do: "EntityMove"
  def packet_name(name), do: name

end
