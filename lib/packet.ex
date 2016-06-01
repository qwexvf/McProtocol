raw_data = McData.Protocol.protocol_data("1.9.2")

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

  @moduledoc """
  Handles encoding and decoding of packets on the lowest level.

  `packet bytes <-> packet struct`
  """

  @callback read(binary) :: struct
  @callback write(struct) :: iolist

  @callback id :: non_neg_integer
  @callback structure :: term

  @callback name :: atom
  @callback state :: atom
  @callback direction :: atom

  @spec id_module(atom, atom, non_neg_integer) :: module
  @doc """
  Gets the packet module for the given direction, mode and id combination.

  The returned module will have this module as it's behaviour.
  """
  def id_module(direction, mode, id)

  @spec module_id(module) :: non_neg_integer
  @doc """
  Gets the packet id for the given packet module.
  """
  def module_id(module)

  for state_packets <- packets, {id, ident, type_name} <- state_packets.packets do
    module = McProtocol.Packet.Utils.make_module_name(state_packets.direction, state_packets.state, ident)

    def id_module(unquote(state_packets.direction), unquote(state_packets.state), unquote(id)), do: unquote(module)
    def module_id(unquote(module)), do: unquote(id)
  end

  def write(%{__struct__: struct_mod} = struct) do
    [
      McProtocol.DataTypes.Encode.varint(apply(struct_mod, :id, [])),
      apply(struct_mod, :write, [struct]),
    ]
  end
  def read(direction, state, id, data) do
    mod = id_module(direction, state, id)
    {resp, ""} = apply(mod, :read, [data])
    resp
  end
  def read(direction, state, data) do
    {id, data} = McProtocol.DataTypes.Decode.varint(data)
    read(direction, state, id, data)
  end

end

{:ok, doc_collector} = McProtocol.Packet.DocCollector.start_link()

for mode <- packets, {id, ident, type_name} <- mode.packets do
  module = McProtocol.Packet.Utils.make_module_name(mode.direction, mode.state, ident)
  compiled = ProtoDef.compile_json_type(mode.types[type_name], ctx)
  fields = Enum.map(compiled.structure, fn {name, _} -> name end)

  doc_data = Map.merge(compiled,
                       %{module: module, id: id, ident: ident, type_name: type_name})
  McProtocol.Packet.DocCollector.collect_packet(doc_collector, doc_data)

  contents = quote do
    @behaviour McProtocol.Packet
    @moduledoc false

    defstruct unquote(Macro.escape(fields))

    # Useful for debugging
    def compiler_output, do: unquote(Macro.escape(compiled))

    def read(unquote(ProtoDef.Type.data_var)) do
      {resp, rest} = unquote(compiled.decoder_ast)
      resp = Map.put(resp, :__struct__, __MODULE__)
      {resp, rest}
    end
    def write(%__MODULE__{} = inp) do
      unquote(ProtoDef.Type.input_var) = Map.delete(inp, :__struct__)
      unquote(compiled.encoder_ast)
    end
    def id, do: unquote(id)
    def structure, do: unquote(Macro.escape(compiled.structure))
    def name, do: unquote(ident)
    def state, do: unquote(mode.state)
    def direction, do: unquote(mode.direction)
  end

  Module.create(module, contents, Macro.Env.location(__ENV__))

end

McProtocol.Packet.DocCollector.finish(doc_collector)
