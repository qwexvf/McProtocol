defmodule McProtocol.EntityMeta do
  alias McProtocol.DataTypes.{Encode, Decode}

  type_idx = [
    byte: 0,
    varint: 1,
    float: 2,
    string: 3,
    chat: 4,
    slot: 5,
    boolean: 6,
    rotation: 7,
    position: 8,
    opt_position: 9,
    direction: 10,
    opt_uuid: 11,
    block_id: 12,
  ]
  for {ident, num} <- type_idx do
    def type_idx(unquote(ident)), do: unquote(num)
    def idx_type(unquote(num)), do: unquote(ident)
  end

  def read(<<0xff::unsigned-1*8, rest::binary>>, entries) do
    {Enum.reverse(entries), rest}
  end
  def read(<<index::unsigned-1*8, rest::binary>>, entries) do
    {type, value, rest} = read_type_body(rest)
    read(rest, [{index, type, value} | entries])
  end

  defp read_type_body(<<type_num::unsigned-1*8, rest::binary>>) do
    type = idx_type(type_num)
    {value, rest} = read_type(rest, type)
    {type, value, rest}
  end

  defp read_type(data, :byte), do: Decode.byte(data)
  defp read_type(data, :varint), do: Decode.varint(data)
  defp read_type(data, :float), do: Decode.float(data)
  defp read_type(data, :string), do: Decode.string(data)
  defp read_type(data, :chat), do: Decode.chat(data)
  defp read_type(data, :slot), do: Decode.slot(data)
  defp read_type(data, :boolean), do: Decode.bool(data)
  defp read_type(data, :rotation), do: Decode.rotation(data)
  defp read_type(data, :position), do: Decode.position(data)
  defp read_type(data, :opt_position) do
    {bool, data} = Decode.bool(data)
    if bool do
      Decode.position(data)
    end
  end
  defp read_type(data, :direction) do
    {direction, data} = Decode.varint(data)
    case direction do
      0 -> :down
      1 -> :up
      2 -> :north
      3 -> :south
      4 -> :west
      5 -> :east
      _ -> raise "Unknown direction: #{direction}"
    end
  end
  defp read_type(data, :opt_uuid) do
    {bool, data} = Decode.bool(data)
    if bool do
      raise "unimplemented"
    end
  end
  defp read_type(data, :block_id), do: Decode.varint(data)

  def write(input), do: write_data(input, [])

  defp write_data([], data), do: [data, <<0xff::unsigned-1*8>>]
  defp write_data([item | rest], data) do
    write_data(rest, [data, write_item(item)])
  end

  defp write_item({index, type, value}) do
    [<<index::unsigned-1*8>>, write_type(type, value)]
  end

  defp write_type(:byte, value), do: Encode.byte(value)
  defp write_type(:varint, value), do: Encode.varint(value)
  defp write_type(:float, value), do: Encode.float(value)
  defp write_type(:string, value), do: Encode.string(value)
  defp write_type(:chat, value), do: Encode.chat(value)

end
