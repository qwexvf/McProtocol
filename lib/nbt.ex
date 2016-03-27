defmodule McProtocol.NBT do

  def read(bin), do: McProtocol.NBT.Read.read(bin)
  def write(struct), do: McProtocol.NBT.Write.write(struct)

  defmodule Read do
    # GZip
    def read_gzip(bin, optional \\ false) do
      read(:zlib.gunzip(bin), optional)
    end
    def read(bin, optional \\ false) do
      {bin, start_tag} = read_tag_id(bin)
      if optional and start_tag == :end do
        nil
      else
        {bin, data} = read_tag(bin, :compound)
        {bin, data}
      end
    end

    defp read_tag_id(<<tag_id::8, bin::binary>>) do
      tag_name = case tag_id do
        0 -> :end
        1 -> :byte
        2 -> :short
        3 -> :int
        4 -> :long
        5 -> :float
        6 -> :double
        7 -> :byte_array
        8 -> :string
        9 -> :list
        10 -> :compound
        11 -> :int_array
      end
      {bin, tag_name}
    end

    defp read_tag(bin) do
      {bin, tag} = read_tag_id(bin)
      read_tag(bin, tag)
    end
    defp read_tag(bin, tag) do
      {bin, name} = read_type(bin, :string)
      {bin, val} = read_type(bin, tag)
      {bin, {tag, name, val}}
    end

    defp read_type(<<val::signed-integer-1*8, bin::binary>>, :byte), do: {bin, val}
    defp read_type(<<val::signed-integer-2*8, bin::binary>>, :short), do: {bin, val}
    defp read_type(<<val::signed-integer-4*8, bin::binary>>, :int), do: {bin, val}
    defp read_type(<<val::signed-integer-8*8, bin::binary>>, :long), do: {bin, val}
    defp read_type(<<val::signed-float-4*8, bin::binary>>, :float), do: {bin, val}
    defp read_type(<<val::signed-float-8*8, bin::binary>>, :double), do: {bin, val}
    defp read_type(bin, :byte_array) do
      <<length::signed-integer-4*8, data::binary-size(length), bin::binary>> = bin
      {bin, data}
    end
    defp read_type(bin, :string) do
      <<length::unsigned-integer-2*8, name::binary-size(length), bin::binary>> = bin
      {bin, to_string(name)}
    end
    defp read_type(bin, :list) do
      {bin, tag} = read_tag_id(bin)
      <<length::signed-integer-4*8, bin::binary>> = bin
      {bin, list} = read_list_item(bin, tag, length, [])
      {bin, list}
    end
    defp read_type(bin, :compound) do
      {bin, tag} = read_tag_id(bin)
      read_compound_item(bin, tag, [])
    end
    defp read_type(bin, :int_array) do
      <<length::signed-integer-4*8, bin::binary>> = bin
      read_int_array(bin, length, [])
    end

    defp read_list_item(bin, _, 0, results) do
      {bin, results}
    end
    defp read_list_item(bin, tag, num, results) when is_integer(num) and num > 0 do
      {bin, val} = read_type(bin, tag)
      read_list_item(bin, tag, num-1, results ++ [{tag, nil, val}])
    end

    defp read_compound_item(bin, :end, results) do
      {bin, results}
    end
    defp read_compound_item(bin, next_tag, results) do
      {bin, result} = read_tag(bin, next_tag)
      {bin, tag} = read_tag_id(bin)
      read_compound_item(bin, tag, results ++ [result])
    end

    defp read_int_array(bin, 0, results) do
      {bin, results}
    end
    defp read_int_array(<<val::signed-integer-4*8, bin::binary>>, num, results) when is_integer(num) and num > 0 do
      read_int_array(bin, num-1, results ++ [val])
    end
  end
  
  defmodule Write do
    def write(struct, optional \\ false) do
      if (!struct or (struct == :nil)) and optional do
        write_tag_id(:end)
      else
        {:compound, name, value} = struct
        write_tag(:compound, name, value)
      end
    end

    defp write_tag_id(tag) do
      num = case tag do
        :end -> 0
        :byte -> 1
        :short -> 2
        :int -> 3
        :long -> 4
        :float -> 5
        :double -> 6
        :byte_array -> 7
        :string -> 8
        :list -> 9
        :compound -> 10
        :int_array -> 11
      end
      <<num::8>>
    end

    defp write_tag(tag, name, value) do
      <<write_tag_id(tag)::binary, write_type(:string, name)::binary, write_type(tag, value)::binary>>
    end

    defp write_type(:byte, value) when is_integer(value), do: <<value::signed-integer-1*8>>
    defp write_type(:short, value) when is_integer(value), do: <<value::signed-integer-2*8>>
    defp write_type(:int, value) when is_integer(value), do: <<value::signed-integer-4*8>>
    defp write_type(:long, value) when is_integer(value), do: <<value::signed-integer-8*8>>
    defp write_type(:float, value) when is_float(value), do: <<value::signed-float-4*8>>
    defp write_type(:double, value) when is_float(value), do: <<value::signed-float-8*8>>
    defp write_type(:byte_array, value) when is_binary(value) do
      [<<byte_size(value)::signed-integer-4*8>>, value]
    end
    defp write_type(:string, value) when is_binary(value) do
      [<<byte_size(value)::unsigned-integer-2*8>>, value]
    end
    defp write_type(:list, values) when is_list(values) do
      {bin, tag} = write_list_values(<<>>, values)
      [write_tag_id(tag), <<write_type(:int, length(values))::binary>>, bin]
    end
    defp write_type(:compound, [{tag, name, value} | rest]) do
      [write_tag(tag, name, value), write_type(:compound, rest)]
    end
    defp write_type(:compound, []) do
      write_tag_id(:end)
    end
    defp write_type(:int_array, values) when is_list(values) do
      [write_type(:int, length(values)), write_int_array_values(values)]
    end

    defp write_list_values(values) do
      {tag, nil, _} = hd(values)
      write_list_values(tag, values)
    end
    defp write_list_values(tag, values) do
      Enum.map(values, fn({f_tag, nil, val}) -> 
        ^tag = f_tag
        write_type(tag, val) 
      end)
    end

    defp write_int_array_values(values) do
      Enum.map(values, fn(value) -> write_type(:int, value) end)
    end

  end

end
