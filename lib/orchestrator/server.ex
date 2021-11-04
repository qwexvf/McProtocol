defmodule McProtocol.Orchestrator.Server do
  @callback handle_next(module, any, any) :: {module, any, any}

  defmacro __using__(_opts) do
    quote do
      use GenServer
      use McProtocol.Orchestrator

      def start_link(connection_pid) do
        IO.puts "start Orchestrator Genserver"
        IO.inspect connection_pid
        GenServer.start_link(__MODULE__, connection_pid)
      end

      def next(orch_pid, last_handler) do
        GenServer.call(orch_pid, {:next, last_handler})
      end

      def handle_call({:next, :connect}, _from, state) do
        {next_handler, args, state} = handle_next(:connect, nil, state)
        {:reply, {next_handler, args}, state}
      end

      def handle_call({:next, {handler_module, return}}, _from, state) do
        {next_handler, args, state} = handle_next(handler_module, return, state)
        {:reply, {next_handler, args}, state}
      end

      defoverridable start_link: 1, next: 2
    end
  end
end
