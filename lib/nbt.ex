defmodule McProtocol.NBT do

  @moduledoc """
  Module for reading and writing NBT (http://wiki.vg/NBT)

  The optional argument on the read/write functions allows the root tag to be nil.
  This encodes as a NBT end tag.
  """

  @type tag_name :: binary | nil

  @type integer_tag :: {:byte | :short | :int | :long, tag_name, integer}
  @type float_tag :: {:float | :double, tag_name, float}
  @type byte_array_tag :: {:byte_array, tag_name, binary}
  @type string_tag :: {:string, tag_name, binary}
  @type list_tag :: {:list, tag_name, [tag]}
  @type compound_tag :: {:compound, tag_name, [tag]}
  @type int_array_tag :: {:int_array, tag_name, [integer]}

  @type tag :: integer_tag | float_tag | byte_array_tag | string_tag | list_tag |
  compound_tag | int_array_tag

  @type t :: compound_tag

  @spec read(binary, boolean) :: t
  def read(bin, optional \\ false), do: McProtocol.NBT.Read.read(bin, optional)

  @spec read_gzip(binary, boolean) :: t
  def read_gzip(bin, optional \\ false), do: McProtocol.NBT.Read.read_gzip(bin, optional)

  @spec write(t, boolean) :: t
  def write(struct, optional \\ false), do: McProtocol.NBT.Write.write(struct, optional)

  defmodule Read do
    @moduledoc false

    def read_gzip(bin, optional \\ false) do
      decomp = :zlib.gunzip(bin)
      read(decomp, optional)
    end
    def read(bin, optional \\ false) do
      {start_tag, bin} = read_tag_id(bin)
      if optional and start_tag == :end do
        nil
      else
        read_tag(:compound, bin)
      end
    end

    defp read_tag_id(<<0::8, bin::binary>>), do: {:end, bin}
    defp read_tag_id(<<1::8, bin::binary>>), do: {:byte, bin}
    defp read_tag_id(<<2::8, bin::binary>>), do: {:short, bin}
    defp read_tag_id(<<3::8, bin::binary>>), do: {:int, bin}
    defp read_tag_id(<<4::8, bin::binary>>), do: {:long, bin}
    defp read_tag_id(<<5::8, bin::binary>>), do: {:float, bin}
    defp read_tag_id(<<6::8, bin::binary>>), do: {:double, bin}
    defp read_tag_id(<<7::8, bin::binary>>), do: {:byte_array, bin}
    defp read_tag_id(<<8::8, bin::binary>>), do: {:string, bin}
    defp read_tag_id(<<9::8, bin::binary>>), do: {:list, bin}
    defp read_tag_id(<<10::8, bin::binary>>), do: {:compound, bin}
    defp read_tag_id(<<11::8, bin::binary>>), do: {:int_array, bin}

    defp read_tag(tag, bin) do
      {name, bin} = read_type(:string, bin)
      {val, bin} = read_type(tag, bin)
      {{tag, name, val}, bin}
    end

    defp read_type(:byte, <<val::signed-integer-1*8, bin::binary>>), do: {val, bin}
    defp read_type(:short, <<val::signed-integer-2*8, bin::binary>>), do: {val, bin}
    defp read_type(:int, <<val::signed-integer-4*8, bin::binary>>), do: {val, bin}
    defp read_type(:long, <<val::signed-integer-8*8, bin::binary>>), do: {val, bin}
    defp read_type(:float, <<val::signed-float-4*8, bin::binary>>), do: {val, bin}
    defp read_type(:double, <<val::signed-float-8*8, bin::binary>>), do: {val, bin}
    defp read_type(:byte_array, bin) do
      <<length::signed-integer-4*8, data::binary-size(length), bin::binary>> = bin
      {data, bin}
    end
    defp read_type(:string, bin) do
      <<length::unsigned-integer-2*8, name::binary-size(length), bin::binary>> = bin
      {to_string(name), bin}
    end
    defp read_type(:list, bin) do
      {tag, bin} = read_tag_id(bin)
      <<length::signed-integer-4*8, bin::binary>> = bin
      read_list_item(bin, tag, length, [])
    end
    defp read_type(:compound, bin) do
      {tag, bin} = read_tag_id(bin)
      read_compound_item(bin, tag, [])
    end
    defp read_type(:int_array, bin) do
      <<length::signed-integer-4*8, bin::binary>> = bin
      read_int_array(bin, length, [])
    end

    defp read_list_item(bin, _, 0, results) do
      {results, bin}
    end
    defp read_list_item(bin, tag, num, results) when is_integer(num) and num > 0 do
      {val, bin} = read_type(tag, bin)
      read_list_item(bin, tag, num-1, results ++ [{tag, nil, val}])
    end

    defp read_compound_item(bin, :end, results) do
      {results, bin}
    end
    defp read_compound_item(bin, next_tag, results) do
      {result, bin} = read_tag(next_tag, bin)
      {tag, bin} = read_tag_id(bin)
      read_compound_item(bin, tag, results ++ [result])
    end

    defp read_int_array(bin, 0, results) do
      {results, bin}
    end
    defp read_int_array(<<val::signed-integer-4*8, bin::binary>>, num, results) when is_integer(num) and num > 0 do
      read_int_array(bin, num-1, results ++ [val])
    end
  end

  defmodule Write do
    @moduledoc false

    def write(struct, optional \\ false) do
      if (!struct or (struct == :nil)) and optional do
        write_tag_id(:end)
      else
        {:compound, name, value} = struct
        IO.iodata_to_binary write_tag(:compound, name, value)
      end
    end

    # Writes a single tag id
    defp write_tag_id(:end), do: <<0::8>>
    defp write_tag_id(:byte), do: <<1::8>>
    defp write_tag_id(:short), do: <<2::8>>
    defp write_tag_id(:int), do: <<3::8>>
    defp write_tag_id(:long), do: <<4::8>>
    defp write_tag_id(:float), do: <<5::8>>
    defp write_tag_id(:double), do: <<6::8>>
    defp write_tag_id(:byte_array), do: <<7::8>>
    defp write_tag_id(:string), do: <<8::8>>
    defp write_tag_id(:list), do: <<9::8>>
    defp write_tag_id(:compound), do: <<10::8>>
    defp write_tag_id(:int_array), do: <<11::8>>

    # Writes a complete tag, including tag type, name and value
    defp write_tag(tag, name, value) do
      [write_tag_id(tag), write_type(:string, name), write_type(tag, value)]
    end

    # Writes a tag value of the supplied type
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
      {bin, tag} = write_list_values(values)
      [write_tag_id(tag), write_type(:int, length(values)), bin]
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
      {write_list_values(tag, values), tag}
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
