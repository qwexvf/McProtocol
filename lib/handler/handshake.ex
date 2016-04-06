defmodule McProtocol.Handler.Handshake do
  use McProtocol.Handler

  alias McProtocol.Packet
  alias McProtocol.Packet.Client

  def parent_handler, do: :connect

  def enter(%{direction: :Client, mode: :Handshake} = stash) do
    {[], nil}
  end

  def state_atom(1), do: :Status
  def state_atom(2), do: :Login

  def handle(packet_in, stash, nil) do
    packet_in = packet_in |> McProtocol.Packet.In.fetch_packet
    packet = %Client.Handshake.SetProtocol{} = packet_in.packet

    mode = state_atom(packet.next_state)

    next = case mode do
      :Status -> {:next, McProtocol.Handler.Status}
      :Login -> :next
    end

    transitions = [
      {:stash,
       %{stash |
         mode: mode,
       }},
      next,
    ]

    {transitions, nil}
  end

  def leave(_stash, nil), do: nil
end
