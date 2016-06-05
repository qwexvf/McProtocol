defmodule McProtocol.Crypto.ServerKeyProvider do
  require Record
  Record.defrecord :rsa_priv_key, :RSAPrivateKey, Record.extract(:RSAPrivateKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  Record.defrecord :rsa_pub_key, :RSAPublicKey, Record.extract(:RSAPublicKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")

  use GenServer

  # Public

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get_keys do
    GenServer.call(__MODULE__, :get_keys)
  end

  # Private

  def init(:ok) do
    # {:ok, private_key_1} = :cutkey.rsa(1024, 65537, return: :key)
    private_key = McProtocol.Util.GenerateRSA.gen(1024)
    private_key_data = rsa_priv_key(private_key)
    public_key = rsa_pub_key(modulus: private_key_data[:modulus], publicExponent: private_key_data[:publicExponent])
    {:SubjectPublicKeyInfo, public_key_asn, :not_encrypted} = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    {:ok, {public_key_asn, private_key}}
  end

  def handle_call(:get_keys, _from, state) do
    {:reply, state, state}
  end
end
