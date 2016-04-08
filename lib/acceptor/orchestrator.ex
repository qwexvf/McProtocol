defmodule McProtocol.Acceptor.Orchestrator do

  @callback start_link(pid) :: {:ok, pid}
  @callback next(pid, {module, any | :crash} | :connect) :: {McProtocol.Handler.Handshake, any}

  defmacro __using__(opts) do
    quote do
      @behaviour McProtocol.Acceptor.Orchestrator

      def start_link(connection_pid) do
        GenServer.start_link(__MODULE__, connection_pid)
      end
      def next(orch_pid, last_handler) do
        GenServer.call(orch_pid, {:next, last_handler})
      end

      defoverridable [start_link: 1, next: 2]
    end
  end

end
