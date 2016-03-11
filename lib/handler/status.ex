defmodule McProtocol.Handler.Status do
  @behaviour McProtocol.Handler

  alias McProtocol.Packets.Client
  alias McProtocol.Packets.Server

  def parent_handler, do: nil

  def initial_state(proto_state = %{ mode: :status }) do
    proto_state
  end

  def handle(packet_data, state) do
    packet = Client.read_packet(packet_data, :status)
    handle_packet(packet, state)
  end

  def handle_packet(%Client.Status.Request{}, state) do
    reply = %Server.Status.Response{response: server_list_response}
    {[{:send_packet, reply}], state}
  end
  def handle_packet(%Client.Status.Ping{payload: payload}, state) do
    reply = %Server.Status.Pong{payload: payload}
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
