defmodule McProtocol.Packet.Decoder do
  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  @moduledoc """

  ## Events emitted

  ### Handshake

  #### From client

  * {:set_mode, mode} - Set the next protocol state. One of :Status or :Login

  ### Status

  #### From client

  * {:start_ping} - Indicates the start of a new ping exchange. Should respond with :server_info
  * {:ping, time} - Should reply with the same event.

  ### Login

  #### From client

  * {:start_login, username} - Indicates the start of a player login.

  """


  # TODO: Implement decoders for Server

  # Handshake

  def decode(%Client.Handshake.SetProtocol{} = packet) do
    mode =
      case packet.next_state do
        1 -> :Status
        2 -> :Login
      end
    [{:set_mode, mode}]
  end

  # Status

  def decode(%Client.Status.PingStart{}), do: [{:ping_start}]
  def decode(%Client.Status.Ping{time: payload}), do: [{:ping, payload}]

  # Login

  def decode(%Client.Login.LoginStart{username: user}), do: {:start_login, user}
  def decode(%Client.Login.EncryptionBegin{}) do
    
  end

end
