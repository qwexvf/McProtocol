defmodule McProtocol.NBTTest do
  use ExUnit.Case, async: true

  test "decode and encode bigtest.nbt" do
    data_compressed = File.read!("test/bigtest.nbt")
    data = :zlib.gunzip(data_compressed)

    {nbt, ""} = McProtocol.NBT.read(data)
    data_encoded = McProtocol.NBT.write(nbt)

    assert data === data_encoded
  end

end
