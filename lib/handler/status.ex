defmodule McProtocol.Handler.Status do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def enter(args, %{direction: :Client, mode: :Status}) do
    {[], [response: server_list_response(Map.get(args, :response, %{}))]}
  end

  def handle(packet_data, stash, state) do
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_data.packet, state)
  end

  def handle_packet(%Client.Status.PingStart{}, [response: response] = state) do
    reply = %Server.Status.ServerInfo{response: response}
    {[{:send_packet, reply}], state}
  end
  def handle_packet(%Client.Status.Ping{time: payload}, state) do
    reply = %Server.Status.Ping{time: payload}

    transitions = [
      {:send_packet, reply},
      :close,
    ]

    {transitions, state}
  end

  def server_list_response(response) do
    %{
      version: %{
        name: "1.9.2",
        protocol: 109,
      },
      players: %{
        max: 0,
        online: 0,
      },
      description: %{
        text: "Minecraft server in Elixir!\nhttps://github.com/McEx/McProtocol",
      },
    }
    |> Map.merge(response)
    |> Poison.encode!
  end

end
