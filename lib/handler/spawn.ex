defmodule McProtocol.Handler.Spawn do
  use McProtocol.Handler

  alias McProtocol.Packet.Client
  alias McProtocol.Packet.Server

  defmodule Config do
    defstruct [game_mode: nil, dimension: nil, difficulty: nil,
               level_type: nil, reduced_debug_info: nil]
  end

  def enter(%Config{} = config,
            %{direction: :Client, mode: :Play, spawned: false} = stash) do
    transitions = [
      {:send_packet,
       %Server.Play.Login{
         entity_id: stash.entity_id,
         game_mode: config.game_mode,
         dimension: config.dimension,
         difficulty: config.difficulty,
         max_players: 100, # TODO: What do?
         level_type: config.level_type,
         reduced_debug_info: config.reduced_debug_info,
       }},
      {:stash, %{stash | spawned: true}},
      {:next, nil},
    ]
    {transitions, %{first: true}}
  end
  def enter(%Config{} = config,
            %{direction: :Client, mode: :Play, spawned: true} = stash) do

    keep_alive_uid = 9001

    transitions = [
      {:send_packet,
       %Server.Play.Respawn{
         dimension: config.dimension,
         difficulty: config.difficulty,
         gamemode: config.game_mode,
         level_type: config.level_type,
       }},
      {:send_packet,
       %Server.Play.EntityStatus{
         entity_id: stash.entity_id,
         entity_status: (if config.reduced_debug_info, do: 22, else: 23),
       }},
      {:send_packet,
       %Server.Play.KeepAlive{
         keep_alive_id: keep_alive_uid,
       }},
    ]

    {transitions, %{first: false, keep_alive_id: keep_alive_uid}}
  end

  def handle(packet_in, stash, state) do
    
  end

end
