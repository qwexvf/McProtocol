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

  def start_link(socket, handler, opts \\ []) do
    GenServer.start_link(__MODULE__, {socket, handler}, opts)
  end

  def init({socket, handler}) do
    initial_proto_state = %{
      mode: :init,
    }
    handler_stack = McProtocol.Handler.handler_stack(handler)
    state = %State{
      socket: socket,
      read_state: McProtocol.Transport.Read.initial_state,
      write_state: McProtocol.Transport.Write.initial_state,
      handler: hd(handler_stack),
      handler_state: apply(hd(handler_stack), :initial_state, [initial_proto_state]),
      handler_stack: tl(handler_stack),
    }
    |> recv_once

    {:ok, state}
  end

  def handle_call({:write_struct, packet_struct}, state) do
    {:reply, :ok, out_write_struct(packet_struct, state)}
  end
  def handle_call({:die_with, pid}, _from, state) do
    Process.link(pid)
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

    state = Enum.reduce(packets, state, fn(packet, inner_state) ->
      handler_args = [packet, inner_state.handler_state]
      {transitions, handler_state} = apply(inner_state.handler, :handle, handler_args)
      inner_state = %{ inner_state | handler_state: handler_state }

      apply_transitions(transitions, inner_state)
    end)
    |> recv_once

    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, state = %State{socket: socket}) do
    {:stop, :tcp_closed, state}
  end

  defp recv_once(state) do
    :inet.setopts(state.socket, active: :once)
    state
  end

  defp out_write_struct(packet, state) do
    packet_data = try do
      McProtocol.Packets.Server.write_packet(packet)
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
  def apply_transition({:next, handler, proto_state}, state) do
    %{ state |
      handler: handler,
      handler_state: apply(handler, :initial_state, [proto_state]),
    }
  end
  def apply_transition({:next, proto_state}, state) do
    stack = state.handler_stack
    apply_transition({:next, hd(stack), proto_state}, %{ state | handler_stack: tl stack})
  end

end
