defmodule McProtocol.Handler.Reset do
  use McProtocol.Handler

  alias McProtocol.Packet.{Client, Server}

  def enter(_, %{direction: :Client, mode: :Play, play_mode: :init} = stash) do
    transitions = [
      {:send_packet,
       %Server.Play.Login{ # See the docs for McProtocol.Handler.play_mode
         entity_id: stash.entity_id,
         game_mode: 0,
         dimension: 0,
         difficulty: 0,
         max_players: 0, # TODO: What do?
         level_type: 0,
         reduced_debug_info: false,
       }},
      {:stash, %{stash | play_mode: :reset}},
      {:next, nil},
    ]
    {transitions, %{first: true}}
  end
  def enter(_, %{direction: :Client, mode: :Play, play_mode: :in_world} = stash) do

    keep_alive_uid = 1

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
      {:stash, %{stash | play_mode: :reset}}
    ]

    {transitions, %{keep_alive_id: keep_alive_uid}}
  end

  def handle(packet_in, stash, state) do
    packet_in = packet_in |> McProtocol.Packet.In.fetch_packet
    handle_packet(packet_in.packet, stash, state)
  end

  def handle_packet(%Client.Play.KeepAlive{keep_alive_id: id} = packet, _stash,
                    %{keep_alive_id: id}) do
    transitions = [
      {:next, nil},
    ]
    {transitions, nil}
  end
  def handle_packet(_packet, _stash, state) do
    {[], state}
  end

end
