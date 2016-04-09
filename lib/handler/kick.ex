defmodule McProtocol.Handler.Kick do
  use McProtocol.Handler

  alias McProtocol.Packet.Server

  def enter(reason, %{direction: :Client, mode: :Login}) do
    transitions = [
      {:send_packet,
       %Server.Login.Disconnect{
         reason: reason,
       }},
      :close
    ]
    {transitions, nil}
  end
  def enter(reason, %{direction: :Client, mode: :Play}) do
    transitions = [
      {:send_packet,
       %Server.Play.KickDisconnect{
         reason: reason,
       }}
    ]
  end

  def handle(_, _, _), do: raise "should not happen"

end
