defmodule McProtocol.Packet.ProtoDefTypes do

  def types, do: %{
    "string" => {:inline, ["pstring", %{"countType" => "varint"}]},
    "slot" => {:simple,
      {__MODULE__, :encode_slot},
      {__MODULE__, :decode_slot}},
    "position" => {:simple,
      {__MODULE__, :encode_position},
      {__MODULE__, :decode_position}},
    "entityMetadata" => {:simple,
      {__MODULE__, :encode_entity_metadata},
      {__MODULE__, :decode_entity_metadata}},
    "UUID" => {:simple,
      {__MODULE__, :encode_uuid},
      {__MODULE__, :decode_uuid}},
    "restBuffer" => {:simple,
      {__MODULE__, :encode_rest},
      {__MODULE__, :decode_rest}},
    "nbt" => {:simple,
      {__MODULE__, :encode_nbt},
      {__MODULE__, :decode_nbt}},
    "optionalNbt" => {:simple,
      {__MODULE__, :encode_optional_nbt},
      {__MODULE__, :decode_optional_nbt}},
  }

  def add_types(ctx) do
    Enum.reduce(types, ctx, fn({name, defin}, ctx) ->
      ProtoDef.Compiler.Context.type_add(ctx, name, defin)
    end)
  end

  def encode_slot(data), do: raise "TODO"
  def decode_slot(data), do: McProtocol.DataTypes.Decode.slot(data)

  def encode_position(data) do
    <<x::signed-integer-26, y::signed-integer-12, z::signed-integer-26, data::binary>> = data
    {{x, y, z}, data}
  end
  def decode_position({x, y, z}) do
    <<x::signed-integer-26, y::signed-integer-12, z::signed-integer-26>>
  end

  def encode_entity_metadata(data), do: McProtocol.EntityMeta.write(data)
  def decode_entity_metadata(data) do
    # FIXME FIXME FIXME
    {data, ret} = McProtocol.EntityMeta.read(data)
    {ret, data}
  end

  def encode_uuid(data) do
    McProtocol.UUID.bin(data)
  end
  def decode_uuid(data) do
    <<uuid_bin::16*8, data::binary>> = data
    uuid = McProtocol.UUID.from_bin(uuid_bin)
    {uuid, data}
  end

  def encode_rest(data), do: data
  def decode_rest(data), do: {data, <<>>}

  def encode_nbt(data), do: McProtocol.NBT.Write.write(data)
  def decode_nbt(data), do: McProtocol.NBT.Read.read(data)

  def encode_optional_nbt(data), do: McProtocol.NBT.Write.write(data, true)
  def decode_optional_nbt(data), do: McProtocol.NBT.Write.read(data, true)

end
