defmodule McProtocol.Handler.Handshake do
  use McProtocol.Handler

  alias McProtocol.Packet
  alias McProtocol.Packet.Client

  def parent_handler, do: :connect

  def enter({:Client, :Handshake}, proto_state) do
    {[], proto_state}
  end

  def state_atom(1), do: :Status
  def state_atom(2), do: :Login

  def handle(packet_in, state) do
    packet_in = packet_in |> McProtocol.Packet.In.fetch_packet
    packet = %Client.Handshake.SetProtocol{} = packet_in.packet

    mode = state_atom(packet.next_state)

    next = case mode do
      :Status -> {:next, McProtocol.Handler.Status, state}
      :Login -> {:next, state}
    end

    {[{:set_mode, mode}, next], state}
  end

  def leave(state), do: state
end
