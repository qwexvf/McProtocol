raw_data = McData.Protocol.protocol_data

packets = raw_data
|> Enum.filter(fn {name, _} -> name != "types" end)
|> Enum.flat_map(fn {state_name, directions} ->
  state = McProtocol.Packet.Utils.state_name_to_ident(state_name)
  Enum.map(directions, fn {direction_name, data} ->
    direction = McProtocol.Packet.Utils.direction_name_to_ident(direction_name)
    types = data["types"]

    packet_map_type = types["packet"]
    packets = McProtocol.Packet.Utils.extract_packet_mappings(packet_map_type)

    %{
      state: state,
      direction: direction,
      packets: packets,
      types: types,
    }
  end)
end)

ctx = ProtoDef.context |> McProtocol.Packet.ProtoDefTypes.add_types

defmodule McProtocol.Packet do

  @callback read(binary) :: struct
  @callback write(struct) :: iolist

  @callback id :: non_neg_integer
  @callback name :: atom
  @callback state :: atom
  @callback direction :: atom

  for state_packets <- packets, {id, ident, type_name} <- state_packets.packets do
    module = McProtocol.Packet.Utils.make_module_name(state_packets.direction, state_packets.state, ident)

    def id_module(unquote(state_packets.direction), unquote(state_packets.state), unquote(id)), do: unquote(module)
    def module_id(unquote(state_packets.direction), unquote(state_packets.state), unquote(module)), do: unquote(id)
  end

  def write(%{__struct__: struct_mod} = struct) do
    [
      McProtocol.DataTypes.Encode.varint(apply(struct_mod, :id, [])),
      apply(struct_mod, :write, [struct]),
    ]
  end
  def read(direction, state, id, data) do
    mod = id_module(direction, state, id)
    apply(mod, :read, [data])
  end

end

for mode <- packets, {id, ident, type_name} <- mode.packets do
  module = McProtocol.Packet.Utils.make_module_name(mode.direction, mode.state, ident)
  compiled = ProtoDef.compile_json_type(mode.types[type_name], ctx)
  fields = Enum.map(compiled.structure, fn {name, _} -> name end)

  contents = quote do
    @behaviour McProtocol.Packet
    @moduledoc false

    defstruct unquote(Macro.escape(fields))

    def read(unquote(ProtoDef.Type.data_var)) do
      unquote(compiled.decoder_ast)
      |> Map.put(:__struct__, __MODULE__)
    end
    def write(%__MODULE__{} = inp) do
      unquote(ProtoDef.Type.input_var) = Map.delete(inp, :__struct__)
      unquote(compiled.encoder_ast)
    end
    def id, do: unquote(id)
    def name, do: unquote(ident)
    def state, do: unquote(mode.state)
    def direction, do: unquote(mode.direction)
  end

  Module.create(module, contents, Macro.Env.location(__ENV__))

end

