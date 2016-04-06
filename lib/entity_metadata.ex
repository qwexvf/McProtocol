defmodule McProtocol.EntityMeta.Util do
  @moduledoc false

  defmacro simple_reader(typ, fun) do
    quote do
      def read_type(unquote(typ), bin) do
        {val, bin} = unquote(fun)(bin)
        {{unquote(typ), val}, bin}
      end
    end
  end
end

defmodule McProtocol.EntityMeta do
  alias McProtocol.DataTypes.Decode
  alias McProtocol.DataTypes.Encode
  import McProtocol.EntityMeta.Util

  @type_idx %{
    byte: 0,
    short: 1,
    int: 2,
    float: 3,
    string: 4,
    slot: 5,
    pos: 6,
    rot: 7
  }
  @idx_type for {type, num} <- @type_idx, into: %{}, do: {num, type}

  def type_idx(type), do: Map.fetch!(@type_idx, type)
  def idx_type(idx), do: Map.fetch!(@idx_type, idx)

  def read(bin, meta \\ []), do: read_r(bin, meta)
  def read_r(<<127::unsigned-integer-1*8, rest::binary>>, meta), do: {meta, rest}
  def read_r(<<key::unsigned-integer-1*5, typ::unsigned-integer-1*3, rest::binary>>, meta) do
    {val, rest} = read_type(typ, rest)
    read_r(rest, [{key, val} | meta])
  end

  def read_type(typ, bin) when is_integer(typ), do: read_type(idx_type(typ), bin)
  def read_type(:pos, bin) do
    {e1, bin} = Decode.int(bin)
    {e2, bin} = Decode.int(bin)
    {e3, bin} = Decode.int(bin)
    {{e1, e2, e3}, bin}
  end
  def read_type(:rot, bin) do
    {e1, bin} = Decode.float(bin)
    {e2, bin} = Decode.float(bin)
    {e3, bin} = Decode.float(bin)
    {{e1, e2, e3}, bin}
  end
  def read_type(typ, bin) when is_atom(typ) do
    type_idx(typ)
    {val, bin} = apply(Decode, typ, [bin])
    {{typ, val}, bin}
  end

  # tail recursion you idiot
  def write([]), do: <<127::unsigned-integer-1*8>>
  def write([item | rest]) do
    write_type(item) <> write(rest)
  end

  def write_type({key, typ, val}) when is_integer(key) do
    idx = type_idx(typ)
    <<key::unsigned-integer-1*5, idx::unsigned-integer-1*3, encode_type(typ, val)::binary>>
  end

  def encode_type(:pos, {e1, e2, e3}) do
    Encode.int(e1) <> Encode.int(e2) <> Encode.int(e3)
  end
  def encode_type(:rot, {e1, e2, e3}) do
    Encode.float(e1) <> Encode.float(e2) <> Encode.float(e3)
  end
  def encode_type(typ, val) when is_atom(typ), do: apply(Encode, typ, [val])

end

defmodule McProtocol.EntityMeta.Names do

  @types [
    {:root, :entity,
     [
       {0, :byte, :entity_status},
       {1, :short, :entity_air},
       {2, :string, :entity_name_tag},
       {3, :byte, :entity_always_show_name_tag},
       {4, :byte, :entity_silent},
     ]},
    {:entity, :entity_lb,
     [
       {6, :float, :entity_lb_health},
       {7, :int, :entity_lb_potion_effect_color},
       {8, :byte, :entity_lb_potion_effect_ambient},
       {9, :byte, :entity_lb_arrows},
     ]},
    {:entity_lb, :entity_l,
     [
       {15, :byte, :entity_l_ai_disabled},
     ]},
    {:entity_l, :human,
     [
       {10, :byte, :human_skin_flags},
       # TODO: 16?
       {17, :float, :human_absorption_hearts},
       {18, :int, :human_score},
     ]},
    {:entity_l, :zombie,
     [
       {12, :byte, :zombie_is_child},
       {13, :byte, :zombie_is_villager},
       {14, :byte, :zombie_is_converting},
     ]},
  ]

  for {parent_class, class, fields} <- @types do
    for {id, type, ident} <- fields do
      def name_id(unquote(class), unquote(ident)), do: {unquote(type), unquote(id)}
      def id_name(unquote(class), unquote(id)), do: {unquote(type), unquote(ident)}
    end
    def name_id(unquote(class), dec_ident), do: name_id(unquote(parent_class), dec_ident)
    def id_name(unquote(class), dec_id), do: id_name(unquote(parent_class), dec_id)
  end
  def id_name(:root, _), do: raise "Unknown metadata"
  def name_id(:root, _), do: raise "Unknown metadata"

end

defmodule McProtocol.EntityMeta.Entity do
  defp t(true), do: 1
  defp t(false), do: 0

  def status({on_fire, crouched, sprinting, using, invisible}) do
    <<num::integer-1*8>> = <<0::integer-1*3, t(invisible)::integer-1*1, t(using)::integer-1*1, t(sprinting)::integer-1*1, 
        t(crouched)::integer-1*1, t(on_fire)::integer-1*1>>
    {0, :byte, num}
  end
end
