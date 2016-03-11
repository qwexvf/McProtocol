defmodule McProtocol.Transport.Read do

  defstruct buffer: "", packet_length: nil, compression: nil, encryption: nil

  # TODO: Make these apply to buffered data when set
  def set_encryption(%__MODULE__{} = state, encr), do: %{ state | encryption: encr }
  def set_compression(%__MODULE__{} = state, compr), do: %{ state | compression: compr }

  def initial_state do
    %__MODULE__{}
  end

  @doc """
    This will take the received data and a read state.
    It returns a list of packet data and a updated read state.
  """
  def process(data, state) do
    {data, state} = decrypt(data, state)
    state = %{ state | buffer: state.buffer <> data }
    decode(state)
  end

  defp decompress(data, state = %{ compression: nil }) do
    {data, state}
  end
  defp decompress(data, state = %{ compression: _threshold }) do
    {packet_length, data} = McProtocol.DataTypes.Decode.varint(data)
    # As per the minecraft protocol, if the varint after the total packet length is 0,
    # the packet is not compressed.
    if packet_length == 0 do
      {data, state}
    else
      {inflate(data), state}
    end
  end

  defp inflate(data) do
    z = :zlib.init
    :zlib.inflateInit(z)
    infl = :zlib.inflate(z, data)
    :zlib.inflateEnd(z)
    :zlib.close(z)
    infl
  end

  defp decrypt(data, state = %{ encryption: nil }) do
    {data, state}
  end
  defp decrypt(data, state = %{ encryption: enc }) do
    {enc, data} = McProtocol.Crypto.Transport.decrypt(data, enc)
    {data, %{ state | encryption: enc }}
  end

  # Quick out.
  defp decode(state = %{ packet_length: nil, buffer: "" }) do
    {[], state}
  end
  # We haven't decoded a packet length yet, if there is enough data, do that and
  # call the decode function with the new state.
  defp decode(state = %{ packet_length: nil }) do
    case McProtocol.DataTypes.Decode.varint?(state.buffer) do
      {:ok, {len, rest}} -> 
        %{ state | 
          packet_length: len, 
          buffer: rest
        }
        |> decode
      :incomplete -> {[], state}
    end
  end
  # We decoded the packet length, but we haven't received enough data to decode
  # the entire packet yet.
  defp decode(state = %{ packet_length: len, buffer: buf }) when len > byte_size(buf) do
    {[], state}
  end
  # We decoded a packet length, and we have enough data to decode a packet.
  defp decode(state) do
    len = state.packet_length

    packet_data = binary_part(state.buffer, 0, state.packet_length)
    packet_rest = binary_part(state.buffer, len, byte_size(state.buffer) - len)

    {packet_data, state} = decompress(packet_data, state)

    {packets, state} = decode(%{ state | buffer: packet_rest, packet_length: nil })
    {[packet_data | packets], state}
  end

  # This performs the final processing of the packet data.
  # This does nothing for now.
  defp decode_packet(packet_data, state) do
    {packet_data, state}
  end

end
