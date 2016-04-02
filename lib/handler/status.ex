defmodule McProtocol.Handler.Status do
  @behaviour McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def parent_handler, do: nil

  def initial_state(proto_state = %{ mode: :status }) do
    proto_state
  end

  def handle(packet_data, state) do
    packet = McProtocol.Packet.read(:Client, :Status, packet_data)
    handle_packet(packet, state)
  end

  def handle_packet(%Client.Status.PingStart{}, state) do
    reply = %Server.Status.ServerInfo{response: server_list_response}
    {[{:send_packet, reply}], state}
  end
  def handle_packet(%Client.Status.Ping{time: payload}, state) do
    reply = %Server.Status.Ping{time: payload}
    {[{:send_packet, reply}], state}
  end

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
