defmodule McProtocol.Handler.Login do
  @behaviour McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def parent_handler, do: McProtocol.Handler.Handshake

  def initial_state(proto_state = %{ mode: :login }) do
    proto_state
  end

  def handle(packet_data, state) do
    packet = McProtocol.Packet.read(:Client, :Login, packet_data)
    handle_packet(packet, state)
  end

  def handle_packet(%Client.Login.LoginStart{username: name}, state) do
    handle_start(!!state[:online_mode], name, state)
  end
  def handle_packet(packet = %Client.Login.EncryptionBegin{}, state) do
    %{ shared_secret: encr_shared_secret, verify_token: encr_token } = packet
    %{ auth_init_data: {{pub_key, priv_key}, token}, name: name } = state

    ^token = :public_key.decrypt_private(encr_token, priv_key)
    shared_secret = :public_key.decrypt_private(encr_shared_secret, priv_key)
    16 = byte_size(shared_secret)

    verification_response = McProtocol.Crypto.Login.verify_user_login(pub_key, shared_secret, name)
    ^name = verification_response.name
    uuid = McProtocol.UUID.from_hex(verification_response.id)

    transitions = [
      {:set_encryption, %McProtocol.Crypto.Transport.CryptData{
          key: shared_secret,
          ivec: shared_secret,
        }}
    ]
    state = %{ state |
      user: {true, name, uuid},
    }
    {transitions_finish, state} = finish_login(state)
    {transitions ++ transitions_finish, state}
  end

  # Online
  def handle_start(true, name, state) do
    auth_init_data = {{pubkey, _}, token} = McProtocol.Crypto.Login.get_auth_init_data

    transitions = [
      {:send_packet, %Server.Login.EncryptionBegin{
          server_id: "",
          public_key: pubkey,
          verify_token: token
        }}
    ]
    state = state
    |> Map.put(:user, {false, name, nil})
    |> Map.put(:auth_init_data, auth_init_data)

    {transitions, state}
  end
  # Offline
  def handle_start(false, name, state) do
    uuid = McProtocol.UUID.uuid4
    state
    |> Map.put(:user, {true, name, uuid})
    |> finish_login
  end

  def finish_login(state) do
    {true, name, uuid} = state.user

    # TODO: Don't make this conversion, should be done in encoder
    uuid_str = McProtocol.UUID.hex_hyphen(uuid)

    transitions = [
      {:send_packet, %Server.Login.Compress{threshold: 256}},
      {:set_compression, 256},
      {:send_packet, %Server.Login.Success{username: name, uuid: uuid_str}},
      {:next, state},
    ]

    {transitions, state}
  end
end
