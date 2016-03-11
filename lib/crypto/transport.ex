defmodule McProtocol.Crypto.Transport do

  defmodule CryptData do
    defstruct key: nil, ivec: nil
  end

  def encrypt(plaintext, %CryptData{} = cryptdata) do
    encrypt(plaintext, cryptdata, [])
  end

  defp encrypt(<<plain_byte::binary-size(1), plain_rest::binary>>, %CryptData{key: key, ivec: ivec} = cryptdata, ciph_base) do
    ciphertext = :crypto.block_encrypt(:aes_cfb8, key, ivec, plain_byte)
    ivec = update_ivec(ivec, ciphertext)
    encrypt(plain_rest, %{cryptdata | ivec: ivec}, [ciph_base, ciphertext])
  end
  defp encrypt(<<>>, %CryptData{} = cryptdata, ciphertext) do
    {cryptdata, IO.iodata_to_binary(ciphertext)}
  end

  def decrypt(ciphertext, %CryptData{} = cryptdata) do
    decrypt(ciphertext, cryptdata, [])
  end

  defp decrypt(<<ciph_byte::binary-size(1), ciph_rest::binary>> = ciph, %CryptData{key: key, ivec: ivec} = cryptdata, plain_base) do
    plaintext = :crypto.block_decrypt(:aes_cfb8, key, ivec, ciph_byte)
    ivec = update_ivec(ivec, ciph_byte)
    decrypt(ciph_rest, %{cryptdata | ivec: ivec}, [plain_base, plaintext])
  end
  defp decrypt(<<>>, %CryptData{} = cryptdata, plaintext) do
    {cryptdata, IO.iodata_to_binary(plaintext)}
  end

  defp update_ivec(ivec, data) when byte_size(data) == 1 and byte_size(ivec) == 16 do
    <<_::binary-size(1), ivec_end::binary-size(15)>> = ivec
    <<ivec_end::binary, data::binary>>
  end

end
