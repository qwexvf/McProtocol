defmodule McProtocol.Acceptor.Connection do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      socket: nil,
      read_state: nil,
      write_state: nil,
      protocol_handler: nil,
      handler: nil,
      handler_state: nil,
      handler_stack: nil,
      stash: nil,
    ]

    def set_encryption(state, encr = %McProtocol.Crypto.Transport.CryptData{}) do
      %{ state |
        read_state: McProtocol.Transport.Read.set_encryption(state.read_state, encr),
        write_state: McProtocol.Transport.Write.set_encryption(state.write_state, encr),
      }
    end
    def set_compression(state, compr) do
      %{ state |
        read_state: McProtocol.Transport.Read.set_compression(state.read_state, compr),
        write_state: McProtocol.Transport.Write.set_compression(state.write_state, compr),
      }
    end

  end

  def start_link(socket, direction, handler, opts \\ []) do
    GenServer.start_link(__MODULE__, {socket, direction, handler}, opts)
  end

  def init({socket, direction, handler}) when direction in [:Client, :Server] do
    handler_stack = McProtocol.Handler.handler_stack(handler)

    connection = %McProtocol.Acceptor.ProtocolState.Connection{
      control: self,
      read: self,
      write: self,
    }

    stash = %McProtocol.Handler.Stash{
      direction: direction,
      connection: connection,
    }

    {transitions, handler_state} = apply(hd(handler_stack), :enter, [stash])

    state = %State{
      socket: socket,
      read_state: McProtocol.Transport.Read.initial_state,
      write_state: McProtocol.Transport.Write.initial_state,
      handler: hd(handler_stack),
      handler_state: handler_state,
      handler_stack: tl(handler_stack),
      stash: stash,
    }
    state = apply_transitions(transitions, state) |> recv_once

    {:ok, state}
  end

  def handle_call({:write_struct, packet_struct}, state) do
    {:reply, :ok, out_write_struct(packet_struct, state)}
  end
  def handle_call({:die_with, pid}, _from, state) do
    Process.link(pid)
    {:reply, :ok, state}
  end

  def handle_cast({:write_struct, packet_struct}, state) do
    {:noreply, out_write_struct(packet_struct, state)}
  end
  def handle_cast({:write_raw, raw}, state) do
    {:noreply, out_write_data(raw, state)}
  end

  def handle_info({:tcp, socket, data}, state = %State{socket: socket}) do
    {packets, read_state} = McProtocol.Transport.Read.process(data, state.read_state)
    state = %{ state | read_state: read_state }

    state = packets
    |> Enum.reduce(state, fn(packet, inner_state) ->
      packet_in = McProtocol.Packet.In.construct(inner_state.stash.direction,
                                                 inner_state.stash.mode, packet)
      handler_args = [packet_in, inner_state.stash, inner_state.handler_state]
      {transitions, handler_state} = apply(inner_state.handler, :handle, handler_args)
      inner_state = %{ inner_state | handler_state: handler_state }

      apply_transitions(transitions, inner_state)
    end)
    |> recv_once

    {:noreply, state}
  end
  def handle_info({:tcp_closed = reason, socket}, state = %State{socket: socket}) do
    Logger.info("Connection #{inspect self} closed: #{inspect reason}")
    {:stop, {:shutdown, :tcp_closed}, state}
  end

  defp recv_once(state) do
    :inet.setopts(state.socket, active: :once)
    state
  end

  defp out_write_struct(packet, state) do
    packet_data = try do
      McProtocol.Packet.write(packet)
    rescue
      error -> handle_write_error(error, packet, state)
    end

    out_write_data(packet_data, state)
  end

  defp handle_write_error(error, struct, state) do
    error_format = Exception.format(:error, error)
    error_msg = error_format <> "When encoding packet:\n" <> inspect(struct) <> "\n"
    Logger.error(error_msg)
    exit(:shutdown)
  end

  defp out_write_data(data, state) do
    write_state = state.write_state
    {out_data, write_state} = McProtocol.Transport.Write.process(data, write_state)
    state = %{ state | write_state: write_state }

    out_socket_write(out_data, state)

    # TODO: This should only be done when big packets are sent
    :erlang.garbage_collect

    state
  end

  defp out_socket_write(data, state) do
    case :gen_tcp.send(state.socket, data) do
      :ok -> :ok
      _ -> raise McProtocol.ClosedError
    end
  end

  def apply_transitions(transitions, state) do
    Enum.reduce(transitions, state, &(apply_transition(&1, &2)))
  end

  def apply_transition({:set_encryption, encr}, state) do
    State.set_encryption(state, encr)
  end
  def apply_transition({:set_compression, compr}, state) do
    State.set_compression(state, compr)
  end
  def apply_transition({:send_packet, packet_struct}, state) do
    out_write_struct(packet_struct, state)
  end
  def apply_transition({:send_data, packet_data}, state) do
    out_write_data(packet_data, state)
  end
  def apply_transition({:stash, %McProtocol.Handler.Stash{} = stash}, state) do
    %{state |
      stash: stash,
     }
  end
  def apply_transition({:next, handler}, state) do
    transition_to_handler(handler, state)
  end
  def apply_transition(:next, state) do
    stack = state.handler_stack
    transition_to_handler(hd(stack), %{state | handler_stack: tl(stack)})
  end

  defp transition_to_handler(handler, state) do
    # TODO: Handle :disconnect?
    apply(state.handler, :leave, [state.stash, state.handler_state])

    {transitions, handler_state} = apply(handler, :enter, [state.stash])

    state =
      %{state |
        handler: handler,
        handler_state: handler_state
       }
    state = apply_transitions(transitions, state)

    state
  end

end
