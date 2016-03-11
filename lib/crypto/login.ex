defmodule McProtocol.Crypto.Login do

  @join_verify_url "https://sessionserver.mojang.com/session/minecraft/hasJoined?"

  defp stupid_sha1(data) do
    <<hash::signed-integer-size(160)>> = :crypto.hash(:sha, data)

    sign = hash < 0
    if sign, do: hash = -hash

    hash_string = String.downcase(Integer.to_string(hash, 16))

    case sign do
      false -> hash_string
      true -> "-" <> hash_string
    end
  end

  def verification_hash(secret, pubkey) do
    stupid_sha1(secret <> pubkey)
  end

  defmodule LoginVerifyResponse do
    defstruct [:id, :name]
  end
  def verify_user_login(pubkey, secret, name) do
    hash = verification_hash(secret, pubkey)
    query = URI.encode_query(%{username: name, serverId: hash})
    response = %{status_code: 200, body: json} = HTTPotion.get(@join_verify_url <> query)
    %{name: ^name} = Poison.decode!(json, as: LoginVerifyResponse)
  end

  def get_auth_init_data(key_server) do
    {McProtocol.Crypto.ServerKeyProvider.get_keys, gen_token}
  end
  defp gen_token do
    :crypto.strong_rand_bytes(16)
  end

end
