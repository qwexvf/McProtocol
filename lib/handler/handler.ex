defmodule McProtocol.Handler do
  @type t :: module
  @moduledoc """
  Basic component for the connection state machine.

  This behaviour is one of the two components that makes McProtocol flexible,
  the other one being the Orchestrator. To interact directly with the protocol
  on the standard acceptor, you need to implement this behavior.

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
  """

  @type protocol_direction :: :Client | :Server
  @type protocol_mode :: :Handshake | :Status | :Login | :Play

  @typedoc """
  The protocol play mode contains additional information on what state the
  connection is in when the protocol_mode is :Play.

  There are currently 3 defined modes:

  * :init - When the connection just switched from the login mode.
  * :reset - The connection has been reset, and is in a well defined state so
  that another handler can take over.
  * :in_world - The player is currently in a world, and you should expect to
  receive movement packets and more from the client. Care should be taken to
  handle things like movement packets when returning the connection to the :reset
  play_mode.

  When the connection play_mode is set to :reset, the connection is required to
  be in the following state:

  * Respawn or Join Game packet has just been sent. (as in not yet spawned in
  world)
  * Gamemode set is 0
  * Dimension set is 0
  * Difficulty set if 0
  * Level type is "default"
  * Reduced Debug Info is false
  """
  @type play_mode :: :init | :reset | :in_world | nil

  @typedoc """
  A command to transition the connection state machine to a new state.

  * set_encryption - Sets the encryption data for both reading and writing.
  * send_packet - Encodes and sends the provided packet struct.
  * send_data - Sends the provided raw data to the socket. DO NOT use.
  * stash - Updates the stash of the socket. When using this, make sure you
  are only updating things you are allowed to touch.
  * handler_process - Tells the connection to monitor this process. If the
  process stops, it will be handled as a handler crash.
  * next - Tells the orchestrator that the handler is done with the connection.
  The second element will be returned to the orchestrator as the handler return
  value.
  * close - There is nothing more that can be done on this connection, and
  it should be closed. Examples of this are when the player has been kicked or
  when the status exchange has been completed.
  """
  @type transition ::{:set_encryption, %McProtocol.Crypto.Transport.CryptData{}}
  | {:set_compression, non_neg_integer}
  | {:send_packet, McProtocol.Packet.t}
  | {:send_data, iodata}
  | {:stash, Stash.t}
  | {:handler_process, pid}
  | {:next, return_value :: any}
  | :close
  @type transitions :: [transition]

  @type handler :: module
  @type handler_state :: term

  @doc """
  This callback is the first thing called when the handler is given control.
  """
  @callback enter(args :: any, stash :: Stash.t) :: {transitions, handler_state}

  @doc """
  When a packet is received on the connection, this callback is called.
  """
  @callback handle(packet :: McProtocol.Packet.In.t, stash :: Stash.t, state :: handler_state) :: {transitions, handler_state}

  @doc """
  This callback the absolute last thing called when control is taken away from
  a handler. You are not able to influence the state of anything related to the
  connection from here, and it should only be used to gracefully stop things
  like related processes.
  """
  @callback leave(stash :: Stash.t, state :: handler_state) :: nil

  defmacro __using__(opts) do
    quote do
      @behaviour McProtocol.Handler

      def leave(_stash, _handler_state), do: nil

      defoverridable [leave: 2]
    end
  end

  defmodule Stash do
    @type t :: %__MODULE__{
      direction: McProtocol.Handler.protocol_direction,
      mode: McProtocol.Handler.protocol_mode,
      play_mode: McProtocol.Handler.play_mode,
      connection: %McProtocol.Acceptor.ProtocolState.Connection{},
      identity: %{authed: boolean, name: String.t, uuid: McProtocol.UUID.t} | nil,
      entity_id: non_neg_integer,
    }

    defstruct(
      direction: nil,
      mode: :Handshake,
      play_mode: nil,
      connection: nil,

      # Stores player identity from the authentication protocol phase.
      identity: nil,

      # Because the entity id of a player can never change once it's set by the
      # server, we need to keep track of this through the lifetime of the connection.
      # Currently set statically to 0 for simplicity.
      entity_id: 0,
    )
  end
end
