defmodule McProtocol.Packet.Utils do
  @moduledoc false

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
      name = packet_name
      |> Macro.camelize
      |> McProtocol.Packet.Overrides.packet_name
      |> String.to_atom
      type_name = name_fields[packet_name]
      {id, name, type_name}
    end)
  end

  def parse_hex_num("0x" <> num) do
    {parsed, ""} = Integer.parse(num, 16)
    parsed
  end

  def make_module_name(direction, state, ident) do
    Module.concat([
      McProtocol.Packet, 
      direction, 
      state, 
      ident
    ])
  end

  def pmap(collection, fun) do
    me = self
    collection
    |> Enum.map(fn (elem) ->
      spawn_link fn -> (send me, { self, fun.(elem) }) end
    end)
    |> Enum.map(fn (pid) ->
      receive do { ^pid, result } -> result end
    end)
  end

end
