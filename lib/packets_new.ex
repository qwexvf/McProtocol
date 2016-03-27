defmodule McProtocol.PacketsNew do

  defmodule Utils do
    def state_name_to_ident("play"), do: :Play
    def state_name_to_ident("handshaking"), do: :Handshake
    def state_name_to_ident("status"), do: :Status
    def state_name_to_ident("login"), do: :Login

    def direction_name_to_ident("toClient"), do: :Server
    def direction_name_to_ident("toServer"), do: :Client

    def extract_packet_mappings(typ) do
      ["container", [id_mapper, name_switch]] = typ

      %{"name" => "name", "type" => ["mapper", %{"mappings" => id_mappings}]} = id_mapper
      %{"name" => "params", "type" => ["switch", %{"fields" => name_fields}]} = name_switch

      Enum.map(id_mappings, fn {hex_id, packet_name} ->
        id = parse_hex_num(hex_id)
        name = String.to_atom(Macro.camelize(packet_name))
        type_name = name_fields[packet_name]
        {id, name, type_name}
      end)
    end

    def parse_hex_num("0x" <> num) do
      {parsed, ""} = Integer.parse(num, 16)
      parsed
    end

    def make_module_name(direction, state, ident) do
      module = Module.concat([
        McProtocol.PacketsNew, 
        direction, 
        state, 
        ident
      ])
    end
  end

  raw_data = McData.Protocol.protocol_data

  general_types = raw_data["types"]
  protocol_states = Enum.filter(raw_data, fn {name, _} -> name != "types" end)

  packets = raw_data
  |> Enum.filter(fn {name, _} -> name != "types" end)
  |> Enum.flat_map(fn {state_name, directions} ->
    state = Utils.state_name_to_ident(state_name)
    Enum.map(directions, fn {direction_name, data} ->
      direction = Utils.direction_name_to_ident(direction_name)
      types = data["types"]

      packet_map_type = types["packet"]
      packets = Utils.extract_packet_mappings(packet_map_type)

      %{
        state: state,
        direction: direction,
        packets: packets,
        types: types,
      }
    end)
  end)

  ctx = ProtoDef.context |> McProtocol.Packets.ProtoDefTypes.add_types

  for state_packets <- packets, {id, ident, type_name} <- state_packets.packets do
    module = Utils.make_module_name(state_packets.direction, state_packets.state, ident)
    compiled = ProtoDef.compile_json_type(state_packets.types[type_name], ctx)
    fields = Enum.map(compiled.structure, fn {name, _} -> name end)

    contents = quote do
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
      def state, do: unquote(state_packets.state)
      def direction, do: unquote(state_packets.direction)
    end
    Module.create(module, contents, Macro.Env.location(__ENV__))

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
