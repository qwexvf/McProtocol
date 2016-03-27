defmodule McProtocol.Packets.Macros do
  defmodule End do
    defmacro __using__(_opts) do
      quote do
        def read_packet_id(data, mode, id) do
          throw "Cannot read packet id #{id} in mode #{mode}"
        end
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import McProtocol.Packets.Macros

      def read_packet(data, mode) do
        {id, data} = McProtocol.DataTypes.Decode.varint(data)
        read_packet_id(data, mode, id)
      end

      def write_packet(struct, mode, name) do
        <<McProtocol.DataTypes.Encode.varint(packet_id(mode, name))::binary, write_packet_name(struct, mode, name)::binary>>
      end
      def write_packet(%{} = struct) do
        <<McProtocol.DataTypes.Encode.varint(packet_id(struct))::binary, write_packet_type(struct)::binary>>
      end
    end
  end

  defmacro packet(mode, id, name, fields) do
    require Mix.Utils

    mode_mod = Mix.Utils.camelize(Atom.to_string(mode))
    name_mod = Mix.Utils.camelize(Atom.to_string(name))
    mod = "#{Atom.to_string(__CALLER__.module)}.#{mode_mod}.#{name_mod}"
    |> String.to_atom

    quote do
      defmodule unquote(mod) do
        defstruct unquote(Keyword.keys(fields))
        def mode, do: unquote(mode)
        def name, do: unquote(name)
        def id, do: unquote(id)
      end
      def read_packet_id(data, unquote(mode), unquote(id)) do
        {decoded, _} = McProtocol.Packets.Macros.decode_packet(data, %unquote(mod){}, unquote(fields))
        Map.put(decoded, :__struct__, unquote(mod))
      end
      def write_packet_name(struct, unquote(mode), unquote(name)) do
        McProtocol.Packets.Macros.encode_packet(struct, unquote(fields))
      end
      def write_packet_type(%unquote(mod){} = struct) do
        McProtocol.Packets.Macros.encode_packet(struct, unquote(fields))
      end
      def packet_name(unquote(mode), unquote(id)), do: unquote(name)
      def packet_name(%unquote(mod){}), do: unquote(name)
      def packet_id(unquote(mode), unquote(name)), do: unquote(id)
      def packet_id(%unquote(mod){}), do: unquote(id)
    end
  end

  defmacro exists_if(conditional_field, value, type) do
    quote do
      {
        fn struct, name -> #encode
          case Map.get(struct, unquote(conditional_field)) do
            unquote(value) -> McProtocol.Packets.Macros.encode_type(struct, name, unquote(type)) #write
            _ -> <<>>
          end
        end,
        fn data, struct, name -> #decode
          case Map.get(struct, unquote(conditional_field)) do
            unquote(value) -> McProtocol.Packets.Macros.decode_type(data, struct, name, unquote(type)) #read
            _ -> {nil, data}
          end
        end
      }
    end
  end

  defmacro array(length_field, fields) do
    quote do
      {
        fn struct, name -> #encode
          items = Map.fetch!(struct, name)
          len = length(items)
          ^len = Map.fetch!(struct, unquote(length_field))
          McProtocol.Packets.Macros.encode_array(items, unquote(fields))
        end,
        fn data, struct, name -> #decode
          len = Map.fetch!(struct, unquote(length_field))
          McProtocol.Packets.Macros.decode_array(data, unquote(fields), [], len)
        end
      }
    end
  end
  
  def encode_array([item | rest], fields) do
    <<encode_packet(item, fields)::binary, encode_array(rest, fields)::binary>>
  end
  def encode_array([], _), do: <<>>
  def decode_array(data, _, array, 0), do: {array, data}
  def decode_array(data, fields, array, num) do
    {decoded, data} = decode_packet(data, %{}, fields)
    decode_array(data, fields, array ++ [decoded], num-1)
  end

  def decode_packet(data, struct, [{name, type} | fields]) do
    {result, data} = decode_type(data, struct, name, type)
    decode_packet(data, Map.put(struct, name, result), fields)
  end
  def decode_packet(data, struct, []) do
    {struct, data}
  end

  def decode_type(data, struct, name, {_, decode_fun}) when is_function(decode_fun, 3) do
    decode_fun.(data, struct, name)
  end
  def decode_type(data, struct, _, {type, args}) when is_atom(type) and is_list(args) do
    apply(McProtocol.DataTypes.Decode, type, [data, struct] ++ args)
  end
  def decode_type(data, struct, _, type) when is_atom(type) do
    apply(McProtocol.DataTypes.Decode, type, [data])
  end

  def encode_packet(struct, [{name, type} | fields]) do
    <<encode_type(struct, name, type)::binary, encode_packet(struct, fields)::binary>>
  end
  def encode_packet(_, []) do
    <<>>
  end

  def encode_type(struct, name, {encode_fun, _}) when is_function(encode_fun, 2) do
    encode_fun.(struct, name)
  end
  def encode_type(struct, name, {type, args}) when is_atom(type) and is_list(args) do
    value = Map.fetch!(struct, name)
    apply(McProtocol.DataTypes.Encode, type, [value, struct] ++ args)
  end
  def encode_type(struct, name, type) when is_atom(type) do
    value = Map.fetch!(struct, name)
    apply(McProtocol.DataTypes.Encode, type, [value])
  end
end
