defmodule McProtocol.Orchestrator do
  @moduledoc """
  Orchestrates what Handler is active at what time.

  While an orchestrator is not able to send or receive data directly on the
  connection, it is able to activate handlers that does so. If you wanted
  to implement something equivalent to BungeeCord, you would implement it
  as an orchestrator.

  A connection has a single orchestrator which is active for the lifetime
  of the connection. If the orchestrator crashes, the connection is
  immediately closed.
  """

  @doc """
  Called when a connection is opened to create a new ochestrator.
  """
  @callback start_link(connection_pid :: pid) :: {:ok, pid}

  @doc """
  Called when a handler has given up control of the connection.
  """
  @callback next(
              orchestrator_pid :: pid,
              last_handler ::
                {McProtocol.Handler.t(), return_val :: any | :crash} | :connect
            ) ::
              {McProtocol.Handler.t(), any}

  defmacro __using__(opts) do
    quote do
      @behaviour McProtocol.Orchestrator
    end
  end
end
