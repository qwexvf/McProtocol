defmodule McProtocol.Handler.Handshake do
  use McProtocol.Handler

  alias McProtocol.Packet
  alias McProtocol.Packet.Client

  def enter(_args, %{direction: :Client, mode: :Handshake} = stash) do
    {[], nil}
  end

  def state_atom(1), do: :Status
  def state_atom(2), do: :Login

  def handle(packet_in, stash, nil) do
    packet_in = packet_in |> McProtocol.Packet.In.fetch_packet
    packet = %Client.Handshake.SetProtocol{} = packet_in.packet

    mode = state_atom(packet.next_state)

    transitions = [
      {:stash,
       %{stash |
         mode: mode,
       }},
      {:next, mode},
    ]

    {transitions, nil}
  end
end
