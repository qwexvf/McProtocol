defmodule McProtocol.Util.GenerateRSA do

  @moduledoc """
  Utilities for generating RSA keys.
  """

  @doc """
  Generates an RSA key with the size of key_size.

  Calls out to the openssl commend line executable for key generation.

  Returns an RSA private key in the form of a :RSAPrivateKey record.
  """
  def gen(key_size) do
    {command, args} = gen_command(key_size)
    {output, 0} = System.cmd(command, args)

    split_output = output
    |> String.split("\n")

    {_, raw_values} = Enum.reduce(split_output, {nil, %{}}, fn(line, {mode, map}) ->
      case is_key(line) do
        :skip -> {mode, map}
        false ->
          {mode, Map.put(map, mode, [line | Map.fetch!(map, mode)])}
        key ->
          {short_key, list_beginning} = decode_key(key)
          {short_key, Map.put(map, short_key, list_beginning)}
      end
    end)

    values = raw_values
    |> Enum.map(fn {k, v} ->
      value = v
      |> Enum.reverse
      |> Enum.map(&String.strip/1)
      |> Enum.join
      |> String.replace(":", "")
      {k, value}
    end)
    |> Enum.into(%{})

    [pub_exp_text, _] = values["publicExponent"] |> String.split(" ")
    {pub_exp, ""} = pub_exp_text |> Integer.parse

    modulus = values["modulus"] |> Base.decode16!(case: :lower) |> as_num
    priv_exp = values["privateExponent"] |> Base.decode16!(case: :lower) |> as_num
    prime_1 = values["prime1"] |> Base.decode16!(case: :lower) |> as_num
    prime_2 = values["prime2"] |> Base.decode16!(case: :lower) |> as_num
    exp_1 = values["exponent1"] |> Base.decode16!(case: :lower) |> as_num
    exp_2 = values["exponent2"] |> Base.decode16!(case: :lower) |> as_num
    coeff = values["coefficient"] |> Base.decode16!(case: :lower) |> as_num

    {:RSAPrivateKey, :"two-prime",
     modulus, pub_exp, priv_exp,
     prime_1, prime_2, exp_1, exp_2, coeff,
     :asn1_NOVALUE}
  end

  defp as_num(bin) do
    size = byte_size(bin)
    <<num::integer-unit(8)-size(size)>> = bin
    num
  end

  defp gen_command(bits) when is_number(bits) do
    {"openssl",
     ["genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:#{bits}", "-text"]}
  end

  defp decode_key(key) do
    [key, list_first] = String.split(key, ":")
    {key, [list_first]}
  end

  defp is_key("-----BEGIN PRIVATE KEY-----"), do: "privateKeyBlock:"
  defp is_key("-----END PRIVATE KEY-----"), do: :skip
  defp is_key(""), do: :skip
  defp is_key(str) do
    cond do
      String.starts_with?(str, "    ") -> false
      match?({:ok, _}, Base.decode64(str)) -> false
      true -> str#binary_part(str, 0, byte_size(str) - 1)
    end
  end

end
