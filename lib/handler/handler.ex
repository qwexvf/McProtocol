defmodule McProtocol.Handler do
  @type transition :: {:set_encryption, %McProtocol.Crypto.Transport.CryptData{}}
                    | {:set_compression, integer}
                    | {:send_packet, McProtocol.Packet.t}
                    | {:send_data, iodata}
                    | {:next, protocol_state}
                    | {:next, handler, protocol_state}

  @type handler_state :: term
  @type protocol_state :: map

  @type handler :: module

  @callback parent_handler :: handler | :connect | nil
  @callback initial_state(protocol_state) :: handler_state
  @callback handle(binary, handler_state) :: {[transition], handler_state}

  def handler_stack(handler) do
    handler_parents(handler, [])
  end

  defp handler_parents(:connect, stack), do: stack
  defp handler_parents(handler, stack) do
    parent = parent(handler)
    handler_parents(parent, [handler | stack])
  end

  defp parent(handler) do
    apply(handler, :parent_handler, [])
  end
end
