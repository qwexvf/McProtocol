defmodule McProtocol.Handler.Login do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  def parent_handler, do: McProtocol.Handler.Handshake

  def enter(%{direction: :Client, mode: :Login}) do
    {[], %{}}
  end

  def handle(packet_in, stash, state) do
    packet_in = packet_in |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_in.packet, stash, state)
  end

  def handle_packet(%Client.Login.LoginStart{username: name}, stash, state) do
    # TODO: Online mode config
    handle_start(false, name, stash, state)
  end
  def handle_packet(packet = %Client.Login.EncryptionBegin{}, stash, state) do
    %{shared_secret: encr_shared_secret, verify_token: encr_token} = packet
    %{auth_init_data: {{pub_key, priv_key}, token}, identity: identity} = state

    ^token = :public_key.decrypt_private(encr_token, priv_key)
    shared_secret = :public_key.decrypt_private(encr_shared_secret, priv_key)
    16 = byte_size(shared_secret)

    verification_response = McProtocol.Crypto.Login.verify_user_login(pub_key, shared_secret,
                                                                      identity.name)
    name = identity.name
    ^name = verification_response.name
    uuid = McProtocol.UUID.from_hex(verification_response.id)

    transitions = [
      {:set_encryption,
       %McProtocol.Crypto.Transport.CryptData{
         key: shared_secret,
         ivec: shared_secret,
       }},
    ]

    identity = %{identity | uuid: uuid}
    state = state
    |> Map.put(:identity, identity)
    |> Map.put(:finished, true)

    {transitions_finish, state} = finish_login(stash, state)
    {transitions ++ transitions_finish, state}
  end

  # Online
  def handle_start(true, name, stash, state) do
    auth_init_data = {{pubkey, _}, token} = McProtocol.Crypto.Login.get_auth_init_data

    transitions = [
      {:send_packet,
       %Server.Login.EncryptionBegin{
         server_id: "",
         public_key: pubkey,
         verify_token: token
       }},
    ]

    state = state
    |> Map.put(:identity, %{online: true, name: name, uuid: nil})
    |> Map.put(:auth_init_data, auth_init_data)

    {transitions, state}
  end
  # Offline
  def handle_start(false, name, stash, state) do
    uuid = McProtocol.UUID.uuid4

    state = state
    |> Map.put(:identity, %{online: false, name: name, uuid: uuid})
    |> Map.put(:finished, true)
    finish_login(stash, state)
  end

  def finish_login(stash, %{finished: true} = state) do
    %{name: name, uuid: uuid} = state.identity
    # TODO: Don't make this conversion, should be done in encoder
    uuid_str = McProtocol.UUID.hex_hyphen(uuid)

    transitions = [
      {:send_packet, %Server.Login.Compress{threshold: 256}},
      {:set_compression, 256},
      {:send_packet, %Server.Login.Success{username: name, uuid: uuid_str}},
      {:stash,
       %{stash |
         identity: state.identity,
         mode: :Play,
        }},
      :next,
    ]

    {transitions, state}
  end

  def leave(_stash, state), do: nil
end
