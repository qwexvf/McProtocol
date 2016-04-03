defmodule McProtocol.Handler.Status do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def parent_handler, do: nil

  def enter({:Client, :Status}, proto_state) do
    {[], proto_state}
  end

  def handle(packet_data, state) do
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_data.packet, state)
  end

  def handle_packet(%Client.Status.PingStart{}, state) do
    reply = %Server.Status.ServerInfo{response: server_list_response}
    {[{:send_packet, reply}], state}
  end
  def handle_packet(%Client.Status.Ping{time: payload}, state) do
    reply = %Server.Status.Ping{time: payload}
    {[{:send_packet, reply}], state}
  end

  def leave(handler_state), do: :disconnect

  def server_list_response do
    Poison.encode!(%{
      version: %{
        name: "1.8.7",
        protocol: 47
      },
      players: %{
        max: 100,
        online: 0,
      },
      description: %{
        text: "Test server in elixir!"
      },
      #favicon: PNG Data
    })
  end

end
