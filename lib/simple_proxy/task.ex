defmodule Mix.Tasks.McProtocol.Proxy do
  use Mix.Task

  @shortdoc "Starts a simple minecraft proxy. For testing, not production."

  def run(args) do
    spawn fn ->
      McProtocol.Acceptor.SimpleAcceptor.accept(25565, &handle_connect(&1))
    end

    Mix.Task.run "run", run_args
  end

  def handle_connect(socket) do
    McProtocol.Acceptor.Connection.start_link(socket, :Client,
                                              McProtocol.SimpleProxy.Orchestrator)
  end

  defp run_args do
    if iex_running?, do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded(IEx) && IEx.started?
  end
end
