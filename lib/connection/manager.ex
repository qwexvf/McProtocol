defmodule McProtocol.Connection.Manager do
  @moduledoc false
  use GenServer
  require Logger

  alias McProtocol.Connection.{Reader, Writer}

  # Client

  def start_link(socket, direction, orch_module, opts \\ []) do
    IO.puts 'manager started'
    GenServer.start_link(__MODULE__, [{socket, direction, orch_module}], opts)
  end

  def start_reading(pid) do
    GenServer.cast(pid, :start_reading)
  end

  # Server

  defstruct socket: nil,
            reader: nil,
            writer: nil,
            stash: nil,
            handler: nil,
            handler_state: nil,
            handler_pid: nil,
            orch_module: nil,
            orch_pid: nil

  @impl true
  def init({socket, direction, orch_module}) do
    control_process = self()

    {:ok, reader} =
      Reader.start_link(socket, fn
        :packet, data -> GenServer.cast(control_process, {:packet, data})
        :closed, :tcp_closed -> GenServer.cast(control_process, :tcp_closed)
      end)

    {:ok, writer} = Writer.start_link(socket)

    connection = %McProtocol.Acceptor.ProtocolState.Connection{
      control: self(),
      reader: reader,
      writer: writer,
      write: fn str ->
        GenServer.cast(control_process, {:write_struct, str})
      end
    }

    stash = %McProtocol.Handler.Stash{
      direction: direction,
      connection: connection
    }

    {:ok, orch_pid} = orch_module.start_link(self())
    {handler, params} = orch_module.next(orch_pid, :connect)
    {transitions, _handler_state} = handler.enter(params, stash)

    state = %__MODULE__{
      socket: socket,
      reader: reader,
      writer: writer,
      stash: stash,
      handler: handler,
      handler_state: nil,
      orch_module: orch_module,
      orch_pid: orch_pid
    }

    state = apply_transitions(transitions, state, {handler, :enter, params})

    {:ok, state}
  end

  @impl true
  def handle_cast(:start_reading, state) do
    :gen_tcp.controlling_process(state.socket, state.reader)
    Reader.start_reading(state.reader)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write_struct, str}, state) do
    Writer.write_struct(state.writer, str)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:packet, data}, state) do
    packet = McProtocol.Packet.In.construct(state.stash.direction, state.stash.mode, data)

    {transitions, handler_state} =
      state.handler.handle(
        packet,
        state.stash,
        state.handler_state
      )

    state = %{state | handler_state: handler_state}

    state = apply_transitions(transitions, state, {state.handler, :next, packet})

    {:noreply, state}
  end

  def apply_transitions(transitions, state, _error_context) do
    Enum.reduce(transitions, state, &apply_transition(&1, &2))
  end

  def apply_transition({:set_encryption, encr}, state) do
    Writer.set_encryption(state.writer, encr)
    Reader.set_encryption(state.reader, encr)
    state
  end

  def apply_transition({:set_compression, compr}, state) do
    Writer.set_compression(state.writer, compr)
    Reader.set_compression(state.reader, compr)
    state
  end

  def apply_transition({:send_packet, packet_struct}, state) do
    Writer.write_struct(state.writer, packet_struct)
    state
    # out_write_struct(packet_struct, state)
  end

  # def apply_transition({:send_data, packet_data}, state) do
  #  out_write_data(packet_data, state)
  # end
  def apply_transition({:stash, %McProtocol.Handler.Stash{} = stash}, state) do
    %{state | stash: stash}
  end

  # TODO:
  # def apply_transition({:handler_process, pid}, %{} = state) when is_pid(pid) do
  #
  # end
  def apply_transition({:next, return}, state) do
    {handler, params} = apply(state.orch_module, :next, [state.orch_pid, {state.handler, return}])

    apply(state.handler, :leave, [state.stash, state.handler_state])
    {transitions, handler_state} = apply(handler, :enter, [params, state.stash])

    state = %{state | handler: handler, handler_state: handler_state}
    state = apply_transitions(transitions, state, {handler, :enter, params})

    state
  end

  def apply_transition(:close, __state) do
    exit(:normal)
  end
end
