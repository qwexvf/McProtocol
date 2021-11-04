defmodule McProtocol.Handler.Proxy do
  use McProtocol.Handler
  use GenServer

  alias McProtocol.Packet.{Client, Server}
  alias McProtocol.Connection.{Reader, Writer}

  defmodule Args do
    defstruct [
      host: nil,
      port: nil,
    ]
  end

  @socket_connect_opts [:binary, packet: :raw, active: false]

  def enter(args = %Args{}, %{direction: :Client, mode: :Play} = stash) do
    {:ok, handler_pid} = GenServer.start(__MODULE__, {args, stash})
    transitions = GenServer.call(handler_pid, {:enter, stash})
    {transitions, handler_pid}
  end

  def handle(packet_data, stash, pid) do
    transitions = GenServer.call(pid, {:client_packet, packet_data, stash})
    {transitions, pid}
  end

  def leave(stash, pid) do
    GenServer.call(pid, {:leave, stash})
    GenServer.stop(pid)
    nil
  end

  # GenServer
  def init({args, _stash}) do
    {:ok, args}
  end

  def handle_call({:enter, stash}, _from, args) do
    {:ok, socket} = :gen_tcp.connect(String.to_char_list(args.host), args.port, @socket_connect_opts)

    control_process = self
    {:ok, reader} = Reader.start_link(socket, fn
      {:packet, data} -> GenServer.call(control_process, {:server_packet, data})
    end)

    {:ok, writer} = Writer.start_link(socket)

    #Writer.write_struct(
    #  writer,
    #  %Client.Handshake.SetProtocol{
    #    
    #  }
    #)

    state = %{
      socket: socket,
      reader: reader,
      writer: writer,
    }

    {:reply, [], state}
  end

  def handle_call({:client_packet, packet, stash}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:server_packet, data}, _from, state) do
    {:reply, :ok, state}
  end
end
