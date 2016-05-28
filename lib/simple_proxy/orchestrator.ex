defmodule McProtocol.SimpleProxy.Orchestrator do
  use McProtocol.Orchestrator.Server

  def init(connection_pid) do
    {:ok, %{connection: connection_pid}}
  end

  def handle_next(:connect, _, state) do
    {McProtocol.Handler.Handshake, %{}, state}
  end
  def handle_next(McProtocol.Handler.Handshake, :Status, state) do
    # TODO: query proxied
    {McProtocol.Handler.Status, %{}, state}
  end
  def handle_next(McProtocol.Handler.Handshake, :Login, state) do
    {McProtocol.Handler.Login, %{}, state}
  end
  def handle_next(McProtocol.Handler.Login, _, state) do
    # {McProtocol.Handler.Kick, %{text: "boo"}, state}
    args = %McProtocol.Handler.Proxy.Args{
      host: "localhost",
      port: 25564,
    }
    {McProtocol.Handler.Proxy, args, state}
  end

end
