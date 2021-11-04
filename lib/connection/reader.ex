defmodule McProtocol.Connection.Reader do
  use GenServer

  alias McProtocol.Transport.Read
  alias McProtocol.Crypto.Transport.CryptData

  # Client

  def start_link(socket, sink) do
    GenServer.start_link(__MODULE__, {socket, sink})
  end

  def start_reading(pid) do
    GenServer.call(pid, :start_reading)
  end

  def set_encryption(pid, encr = %CryptData{}) do
    GenServer.call(pid, {:set_encryption, encr})
  end

  def set_compression(pid, compr) do
    GenServer.call(pid, {:set_compression, compr})
  end

  # Server

  defstruct state: :init,
            socket: nil,
            read_state: nil,
            sink: nil

  def init({socket, sink_fun}) do
    state = %__MODULE__{
      socket: socket,
      read_state: Read.initial_state(),
      sink: sink_fun
    }

    {:ok, state}
  end

  def handle_call(:start_reading, _from, state = %__MODULE__{state: :init}) do
    state =
      %{state | state: :started}
      |> recv_once

    {:reply, :ok, state}
  end

  def handle_call({:set_encryption, encr}, _from, state) do
    read_state = Read.set_encryption(state.read_state, encr)
    state = %{state | read_state: read_state}
    {:reply, :ok, state}
  end

  def handle_call({:set_compression, encr}, _from, state) do
    read_state = Read.set_compression(state.read_state, encr)
    state = %{state | read_state: read_state}
    {:reply, :ok, state}
  end

  def handle_info(
        {:tcp, socket, data},
        state = %__MODULE__{socket: socket, state: :started}
      ) do
    {packets, read_state} = Read.process(data, state.read_state)

    Enum.map(packets, &state.sink.(:packet, &1))

    state =
      %{state | read_state: read_state}
      |> recv_once

    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state = %__MODULE__{socket: socket}) do
    state.sink.(:closed, :tcp_closed)
    {:stop, {:shutdown, :tcp_closed}, state}
  end

  defp recv_once(state) do
    :inet.setopts(state.socket, active: :once)
    state
  end
end
