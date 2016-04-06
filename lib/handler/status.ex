defmodule McProtocol.Handler.Status do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def parent_handler, do: nil

  def enter(%{direction: :Client, mode: :Status}) do
    {[], nil}
  end

  def handle(packet_data, stash, s) do
    IO.inspect s
    packet_data = packet_data |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_data.packet)
  end

  def handle_packet(%Client.Status.PingStart{}) do
    reply = %Server.Status.ServerInfo{response: server_list_response}
    {[{:send_packet, reply}], nil}
  end
  def handle_packet(%Client.Status.Ping{time: payload}) do
    reply = %Server.Status.Ping{time: payload}
    {[{:send_packet, reply}], nil}
  end

  def leave(_stash, nil), do: :disconnect

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
