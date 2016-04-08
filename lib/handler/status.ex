defmodule McProtocol.Handler.Status do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def enter(_args, %{direction: :Client, mode: :Status}) do
    {[], nil}
  end

  def handle(packet_data, stash, _state) do
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_data.packet)
  end

  def handle_packet(%Client.Status.PingStart{}) do
    reply = %Server.Status.ServerInfo{response: server_list_response}
    {[{:send_packet, reply}], nil}
  end
  def handle_packet(%Client.Status.Ping{time: payload}) do
    reply = %Server.Status.Ping{time: payload}

    transitions = [
      {:send_packet, reply},
      :close,
    ]

    {transitions, nil}
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
