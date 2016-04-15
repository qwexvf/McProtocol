defmodule McProtocol.Handler.Kick do
  use McProtocol.Handler

  @moduledoc """
  Kicks the player from the server with a message. Can be used in Login and Play.

  The argument should be a map in the Chat format.
  """

  alias McProtocol.Packet.Server

  def enter(reason, %{direction: :Client, mode: :Login}) do
    transitions = [
      {:send_packet,
       %Server.Login.Disconnect{
         reason: Poison.encode!(reason),
       }},
      :close,
    ]
    {transitions, nil}
  end
  def enter(reason, %{direction: :Client, mode: :Play}) do
    transitions = [
      {:send_packet,
       %Server.Play.KickDisconnect{
         reason: Poison.encode!(reason),
       }},
      :close,
    ]
    {transitions, nil}
  end

  def handle(_, _, _), do: raise "should never happen"

end
