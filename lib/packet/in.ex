defmodule McProtocol.Packet.In do

  @moduledoc """
  This represents a packet being received from a Server or Client.

  This abstraction ensures that a packet is only decoded if it's actually needed. A proxy
  could look at the packet type, if it doesn't need to touch it, it could send on the raw
  data without even decoding it.

  Even if there are several layers calling fetch_packet/1, this also ensures that the
  packet data is only decoded once. If fetch_packet/1 is never called, the packet is never
  decoded.
  """

  @type t :: %__MODULE__{}

  @directions [:Client, :Server]
  @modes [:Handshake, :Status, :Login, :Play]

  defstruct direction: nil, mode: nil, id: nil, module: nil, raw: nil, packet: nil

  @spec construct(atom, atom, binary) :: t
  @doc """
  Constructs a new In struct, without decoding the packet data. This function would most
  likely be used in the part of your application that receives the packets from the network.

  If you use the supplied Acceptor, you should not need to use this.
  """
  def construct(direction, mode, raw) when direction in @directions and mode in @modes do
    # A packet always starts with a packet ID, read that.
    {id, raw} = McProtocol.DataTypes.Decode.varint(raw)
    module = McProtocol.Packet.id_module(direction, mode, id)

    %__MODULE__{
      direction: direction,
      mode: mode,
      id: id,
      module: module,
      raw: raw,
    }
  end

  @spec fetch_packet(%McProtocol.Packet.In{}) :: t
  @doc """
  Ensures that the packet is decoded. After this call has succeeded, the packet field of
  the returned struct is guaranteed to be set.
  """
  def fetch_packet(%__MODULE__{packet: nil, module: mod, raw: raw} = holder) do
    {packet, ""} = apply(mod, :read, [raw])
    %{ holder |
      packet: packet,
    }
  end
  # We already decoded the packet, don't do it again
  def fetch_packet(%__MODULE__{} = holder), do: holder

end
