defmodule McProtocol.Handler do
  @moduledoc """
  Basic component for the connection state machine.

  This behaviour is what makes McProtocol flexible. To work with the standard
  acceptor, you need to implement the behaviour defined in this module.

  ## Interaction

  A handler has two ways to interact with the connection it's associated with,
  synchronous, and asynchronous.

  Synchronous interaction is named a transition (it transitions the connection
  state machine into a new state). Transitions can do things like set protocol
  encryption, send packets, raw data, or transition to a new protocol state. It
  allows you to control the precise order of operations.

  (Most of this is not done yet) Asynchronous interaction is done by messaging.
  Any process can interact with any connection, as long as it has the pid and
  state cookie. Because the exact order of operations can not be controlled,
  things like setting encryption or compression is not possible.

  ## Handler stacks

  The minecraft protocol has some common, easily reusable stages, like
  handshake, status or login. Handlers combined with handler stacks makes it
  easy to separate these things into small, reusable modules. When designing
  something like a custom server, you could define a parent_handler/0 function
  that returns McProtocol.Handler.Login. The acceptor would then traverse
  upwards, grabbing the parent handler of each parent until it hits :connect, in
  this case McProtocol.Handler.Handshake. It would start there, go back up the
  chain until control is given to your handler.
  """

  @type protocol_direction :: :Client | :Server
  @type protocol_mode :: :Handshake | :Status | :Login | :Play

  @type transition ::{:set_encryption, %McProtocol.Crypto.Transport.CryptData{}}
  | {:set_compression, integer}
  | {:send_packet, McProtocol.Packet.t}
  | {:send_data, iodata}
  | {:stash, Stash.t}
  | {:handler_process, pid}
  | :next
  | {:next, handler}
  @type transitions :: [transition]

  @type handler :: module
  @type handler_state :: term

  @callback parent_handler :: handler | :connect | nil
  @callback enter(Stash.t) :: {transitions, handler_state}
  @callback handle(McProtocol.Packet.In.t, Stash.t, handler_state) :: {transitions, handler_state}
  @callback leave(Stash.t, handler_state) :: nil | :disconnect

  defmacro __using__(opts) do
    quote do
      @behaviour McProtocol.Handler

      def parent_handler, do: nil

      defoverridable [parent_handler: 0]
    end
  end

  defmodule Stash do
    @type t :: %__MODULE__{
      direction: McProtocol.Handler.protocol_direction,
      mode: McProtocol.Handler.protocol_mode,
      connection: %McProtocol.Acceptor.ProtocolState.Connection{},
      identity: %{authed: boolean, name: String.t, uuid: McProtocol.UUID.t} | nil,
      entity_id: non_neg_integer,
    }

    defstruct(
      direction: nil,
      mode: :Handshake,
      connection: nil,

      # Stores player identity from the authentication protocol phase.
      identity: nil,

      # Because the entity id of a player can never change once it's set by the
      # server, we need to keep track of this through the lifetime of the connection.
      # Currently set statically to 0 for simplicity.
      entity_id: 0,
    )
  end

  def handler_stack(handler) do
    handler_parents(handler, [])
  end

  defp handler_parents(nil, _) do
    raise "Invalid handler stack. Every parent must return either a handler module or :connect."
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
