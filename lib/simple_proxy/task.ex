defmodule Mix.Tasks.McProtocol.Proxy do
  use Mix.Task

  @shortdoc "Starts a simple minecraft proxy. For testing, not production."

  def run(args) do
    # spawn fn ->
    #  McProtocol.Acceptor.SimpleAcceptor.accept(25565, &handle_connect(&1))
    # end
    spawn(fn -> acceptor() end)

    Mix.Task.run("run", run_args())
  end

  def acceptor do
    IO.puts "asdfasdf acceptor"
    McProtocol.Acceptor.SimpleAcceptor.accept(
      25_565,
      fn socket ->
        IO.puts "start connection manager"
        require IEx; IEx.pry()
        McProtocol.Connection.Manager.start_link(
          socket,
          :Client,
          McProtocol.SimpleProxy.Orchestrator
        )
      end,
      fn pid, _socket ->
        IO.puts "start connection manager"
        McProtocol.Connection.Manager.start_reading(pid)
      end
    )
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded(IEx) && IEx.started?()
  end
end
