defmodule McProtocol.Connection.Writer do
  use GenServer
  require Logger

  alias McProtocol.Transport.Write
  alias McProtocol.Crypto.Transport.CryptData

  # Client

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def write_struct(pid, packet) do
    GenServer.cast(pid, {:write_struct, packet})
  end
  def write_raw(pid, data) do
    GenServer.cast(pid, {:write_raw, data})
  end

  def set_encryption(pid, encr = %CryptData{}) do
    GenServer.call(pid, {:set_encryption, encr})
  end
  def set_compression(pid, compr) do
    GenServer.call(pid, {:set_compression, compr})
  end

  # Server

  defstruct [
    socket: nil,
    write_state: nil,
  ]

  def init(socket) do
    state = %__MODULE__{
      socket: socket,
      write_state: Write.initial_state,
    }
    {:ok, state}
  end

  def handle_cast({:write_struct, packet}, state) do
    state = out_write_struct(packet, state)
    {:noreply, state}
  end
  def handle_cast({:write_raw, data}, state) do
    state = out_write_data(data, state)
    {:noreply, state}
  end

  def handle_call({:set_encryption, encr}, _from, state) do
    write_state = Write.set_encryption(state.write_state, encr)
    state = %{state | write_state: write_state}
    {:reply, :ok, state}
  end
  def handle_call({:set_compression, compr}, _from, state) do
    write_state = Write.set_compression(state.write_state, compr)
    state = %{state | write_state: write_state}
    {:reply, :ok, state}
  end

  def out_write_struct(packet, state) do
    packet_data =
      try do
        McProtocol.Packet.write(packet)
      rescue
        error -> handle_write_error(error, packet, state)
      end

    out_write_data(packet_data, state)
  end

  def out_write_data(data, state) do
    {out_data, write_state} = Write.process(data, state.write_state)
    state = %{state | write_state: write_state}

    :ok = socket_write_raw(out_data, state)

    # TODO: This should only be done when big packets are sent
    :erlang.garbage_collect

    state
  end

  def socket_write_raw(data, state) do
    case :gen_tcp.send(state.socket, data) do
      :ok -> :ok
      # This might seem like a REALLY bad idea, and it probably is,
      # but a socket closed error should be handled by the reader process,
      # as that is what actually gets notified of it.
      # Handling it in one place makes things easier for us.
      _ -> :ok
    end
  end

  defp handle_write_error(error, struct, state) do
    error_format = Exception.format(:error, error)
    error_msg = error_format <> "When encoding packet:\n" <> inspect(struct) <> "\n"
    Logger.error(error_msg)
    exit(:packet_write_error)
  end

end
