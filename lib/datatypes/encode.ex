defmodule McProtocol.DataTypes.Encode do
  def byte_flags(bin) do
    bin
  end

  @spec varint(integer) :: binary
  def varint(num) when num <= 127, do: <<0::1, num::7>>
  def varint(num) when num >= 128 do
    <<1::1, band(num, 127)::7, varint(num >>> 7)::binary>>
  end

  @spec bool(boolean) :: binary
  def bool(bool) do
    if bool do
      <<1::size(8)>>
    else
      <<0::size(8)>>
    end
  end

  def string(string) do
    <<varint(IO.iodata_length(string))::binary, IO.iodata_to_binary(string)::binary>>
  end
  def chat(struct) do
    string(Poison.Encoder.encode(struct, []))
  end

  def slot(%McProtocol.DataTypes.Slot{id: nil}), do: <<-1::signed-integer-2*8>>
  def slot(%McProtocol.DataTypes.Slot{id: -1}), do: <<-1::signed-integer-2*8>>
  def slot(nil), do: <<-1::signed-integer-2*8>>
  def slot(%McProtocol.DataTypes.Slot{} = slot) do
    [ <<slot.id::unsigned-integer-2*8,
      slot.count::unsigned-integer-1*8,
      slot.damage::unsigned-integer-2*8>>,
      McProtocol.NBT.write(slot.nbt, true)]
  end

  def varint_length_binary(data) do
    <<varint(byte_size(data))::binary, data::binary>>
  end

  def byte(num) when is_integer(num) do
    <<num::signed-integer-1*8>>
  end
  def fixed_point_byte(num) do
    byte(round(num * 32))
  end
  def u_byte(num) do
    <<num::unsigned-integer-size(8)>>
  end

  def short(num) do
    <<num::unsigned-integer-size(16)>>
  end
  def u_short(num) do
    <<num::unsigned-integer-size(16)>>
  end

  def int(num) do
    <<num::signed-integer-size(32)>>
  end
  def fixed_point_int(num) do
    int(round(num * 32))
  end
  def long(num) do
    <<num::signed-integer-size(64)>>
  end

  def float(num) do
    <<num::signed-float-4*8>>
  end
  def double(num) do
    <<num::signed-float-8*8>>
  end

  def position({x, y, z}) do
    <<x::signed-integer-26, y::signed-integer-12, z::signed-integer-26>>
  end

  def data(data) do
    data
  end

  def uuid_string(%McProtocol.UUID{} = dat) do
    string(McProtocol.UUID.hex_hyphen(dat))
  end
  def uuid(%McProtocol.UUID{} = dat) do
    #<<num::signed-integer-16*8>>
    McProtocol.UUID.bin dat
  end

  def angle(num) do
    byte(num)
  end
  def metadata(meta) do
    McProtocol.EntityMeta.write(meta)
  end
end
