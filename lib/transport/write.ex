defmodule McProtocol.Transport.Write do

  defstruct compression: nil, encryption: nil

  def set_encryption(%__MODULE__{} = state, encr), do: %{ state | encryption: encr }
  def set_compression(%__MODULE__{} = state, compr), do: %{ state | compression: compr }

  def initial_state do
    %__MODULE__{}
  end

  def process(data, state) do
    data_len = IO.iodata_length(data)

    compressed = compress(data, data_len, state)
    compressed_len = IO.iodata_length(compressed)

    compressed_len_encoded = McProtocol.DataTypes.Encode.varint(compressed_len)
    complete = [compressed_len_encoded, compressed]

    {compressed, state} = encrypt(complete, state)

    {compressed, state}
  end

  defp encrypt(data, state = %{ encryption: nil }) do
    {data, state}
  end
  defp encrypt(data, state = %{ encryption: encr_data }) do
    data = IO.iodata_to_binary(data)
    {encr_data, ciphertext} = McProtocol.Crypto.Transport.encrypt(data, encr_data)
    {ciphertext, %{ state | encryption: encr_data }}
  end

  defp compress(data, _data_size, %{ compression: nil }) do
    data
  end
  defp compress(data, data_size, %{ compression: thr }) when data_size > thr do
    compressed = deflate(data)
    data_size_encoded = McProtocol.DataTypes.Encode.varint(data_size)
    [data_size_encoded, compressed]
  end
  defp compress(data, _data_size, _state) do
    [0, data]
  end

  defp deflate(data) do
    # TODO: Reuse zstream
    z = :zlib.open
    :zlib.deflateInit(z)
    compr = :zlib.deflate(z, data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    compr
  end

end
