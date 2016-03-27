defmodule McProtocol.Packet do
  @type t :: struct
end

defmodule McProtocol.Packets.Client do #Serverbound
  use McProtocol.Packets.Macros

  packet :init, 0x00, :handshake,
    protocol_version: :varint, 
    server_address: :string,
    server_port: :u_short,
    next_mode: :varint

  packet :status, 0x00, :request, []
  packet :status, 0x01, :ping, payload: :long

  packet :login, 0x00, :login_start,
    name: :string
  packet :login, 0x01, :encryption_response,
    shared_secret: :varint_length_binary,
    verify_token: :varint_length_binary

  packet :play, 0x00, :keep_alive,
    nonce: :varint
  packet :play, 0x01, :chat_message,
    message: :string
  packet :play, 0x02, :use_entity,
    target: :varint,
    type: :varing,
    target_x: exists_if(:type, 2, :float),
    target_y: exists_if(:type, 2, :float),
    target_z: exists_if(:type, 2, :float)
  packet :play, 0x03, :player_ground,
    on_ground: :bool
  packet :play, 0x04, :player_position,
    x: :double,
    y: :double,
    z: :double,
    on_ground: :bool
  packet :play, 0x05, :player_look,
    yaw: :float,
    pitch: :float,
    on_ground: :bool
  packet :play, 0x06, :player_position_look,
    x: :double,
    y: :double,
    z: :double,
    yaw: :float,
    pitch: :float,
    on_ground: :bool
  packet :play, 0x07, :player_digging,
    status: :byte,
    location: :position,
    face: :byte
  packet :play, 0x08, :player_block_placement,
    location: :position,
    face: :byte,
    held_item: :slot,
    cursor_x: :byte,
    cursor_y: :byte,
    cursor_z: :byte
  packet :play, 0x09, :held_item_change,
    slot: :short
  packet :play, 0x0a, :animation, []
  packet :play, 0x0b, :entity_action,
    entity_id: :varint,
    action_id: :varint,
    jump_boost: :varint
  packet :play, 0x0c, :steer_vehicle,
    sideways: :float,
    forward: :float,
    flags: :byte
  packet :play, 0x0d, :close_window,
    window_id: :u_byte
  packet :play, 0x0e, :click_window,
    window_id: :u_byte,
    slot: :short,
    button: :byte,
    action_number: :short,
    mode: :byte,
    clicked_item: :slot
  packet :play, 0x0f, :confirm_transaction, #TODO: Figure out why this is sent serverbound..
    window_id: :u_byte,
    action_number: :short,
    accepted: :boolean
  packet :play, 0x10, :creative_inventory_action,
    slot: :short,
    item: :slot
  packet :play, 0x11, :enchant_item,
    window_id: :byte,
    enchantment: :byte
  packet :play, 0x12, :update_sign,
    location: :position,
    line_1: :chat,
    line_2: :chat,
    line_3: :chat,
    line_4: :chat
  packet :play, 0x13, :player_abilities,
    flags: :byte_flags,
    flying_speed: :float,
    walking_speed: :float
  packet :play, 0x14, :tab_complete,
    text: :string,
    has_look: :bool,
    block_look: exists_if(:has_look, true, :position)
  packet :play, 0x15, :client_settings,
    locale: :string,
    view_distance: :byte,
    chat_mode: :byte,
    chat_colors: :bool,
    skin_parts: :byte_flags
  packet :play, 0x16, :client_status,
    action_id: :varint #0: perform respawn, 1: request stats, 2: taking inventory achivement
  packet :play, 0x17, :plugin_message,
    channel: :string,
    data: :byte_array_rest
  packet :play, 0x18, :spectate,
    target_player: :uuid
  packet :play, 0x19, :resource_pack_status,
    hash: :string,
    result: :varint

  use McProtocol.Packets.Macros.End
end

defmodule McProtocol.Packets.Server do #Clientbound
  use McProtocol.Packets.Macros

  packet :status, 0x00, :response, response: :string
  packet :status, 0x01, :pong, payload: :long

  packet :login, 0x00, :disconnect, reason: :chat
  packet :login, 0x01, :encryption_request, 
    server_id: :string,
    public_key: :varint_length_binary,
    verify_token: :varint_length_binary
  packet :login, 0x02, :login_success,
    uuid: :uuid_string,
    username: :string
  packet :login, 0x03, :set_compression,
    threshold: :varint

  packet :play, 0x00, :keep_alive,
    nonce: :varint
  packet :play, 0x01, :join_game,
    entity_id: :int,
    gamemode: :u_byte,
    dimension: :byte,
    difficulty: :u_byte,
    max_players: :u_byte,
    level_type: :string,
    reduced_debug_info: :bool
  packet :play, 0x02, :chat_message,
    data: :chat,
    position: :byte
  packet :play, 0x03, :time_update,
    world_age: :long,
    time_of_day: :long
  packet :play, 0x04, :entity_equipment,
    entity_id: :varint,
    slot: :short,
    item: :slot
  packet :play, 0x05, :spawn_position,
    location: :position
  packet :play, 0x06, :update_health,
    health: :float,
    food: :varint,
    food_saturation: :float
  packet :play, 0x07, :respawn,
    dimension: :int,
    difficulty: :u_byte,
    gamemode: :u_byte,
    level_type: :string
  packet :play, 0x08, :player_position_look,
    x: :double,
    y: :double,
    z: :double,
    yaw: :float,
    pitch: :float,
    flags: :byte #X, Y, Z, X_ROT, Y_ROT. If set, update is relative.
  packet :play, 0x09, :held_item_change,
    slot: :byte
  packet :play, 0x0a, :use_bed,
    entity_id: :varint,
    location: :position
  packet :play, 0x0b, :animation,
    entity_id: :varint,
    animation: :u_byte
  packet :play, 0x0c, :spawn_player,
    entity_id: :varint,
    player_uuid: :uuid,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    current_item: :short,
    metadata: :metadata
  packet :play, 0x0d, :collect_item,
    collected_id: :varint, #(entity ids)
    collector_id: :varint
  packet :play, 0x0e, :spawn_object,
    entity_id: :varint,
    type: :byte,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    data: :object_data
  packet :play, 0x0f, :spawn_mob,
    entity_id: :varint,
    type: :byte,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    head_pitch: :angle,
    velocity_x: :short,
    velocity_y: :short,
    velocity_z: :short,
    metadata: :metadata
  packet :play, 0x10, :spawn_painting,
    entity_id: :varint,
    title: :string,
    location: :position,
    direction: :u_byte
  packet :play, 0x11, :spawn_experience_orb,
    entity_id: :varint,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    count: :short
  packet :play, 0x12, :entity_velocity,
    entity_id: :varint,
    velocity_x: :short,
    velocity_y: :short,
    velocity_z: :short
  #TODO: Packet 0x13
  packet :play, 0x14, :entity, #Entity "ping" packet
    entity_id: :varint
  packet :play, 0x15, :entity_relative_move,
    entity_id: :varint,
    delta_x: :fixed_point_byte,
    delta_y: :fixed_point_byte,
    delta_z: :fixed_point_byte,
    on_ground: :bool
  packet :play, 0x16, :entity_look,
    entity_id: :varint,
    yaw: :angle, #not delta
    pitch: :angle, #^
    on_ground: :bool
  packet :play, 0x17, :entity_look_relative_move,
    entity_id: :varint,
    delta_x: :fixed_point_byte,
    delta_y: :fixed_point_byte,
    delta_z: :fixed_point_byte,
    yaw: :angle, #not delta
    pitch: :angle, #^
    on_ground: :bool
  packet :play, 0x18, :entity_teleport,
    entity_id: :varint,
    x: :fixed_point_int,
    y: :fixed_point_int,
    z: :fixed_point_int,
    yaw: :angle,
    pitch: :angle,
    on_ground: :bool
  packet :play, 0x19, :entity_head_look,
    entity_id: :varint,
    head_yaw: :angle #not delta
  packet :play, 0x1a, :entity_status,
    entity_id: :int, #Why the fuck would you use an int here?...
    entity_status: :byte
  packet :play, 0x1b, :attach_entity,
    entity_id: :int, #...
    vehicle_id: :int,
    leash: :bool
  packet :play, 0x1c, :entity_metadata,
    entity_id: :varint,
    metadata: :metadata
  packet :play, 0x1d, :entity_effect,
    entity_id: :varint,
    effect_id: :byte,
    amplifier: :byte,
    duration: :varint, #seconds
    hide_particles: :bool
  packet :play, 0x1e, :remove_entity_effect,
    entity_id: :varint,
    effect_id: :byte
  packet :play, 0x1f, :set_experience,
    experience_bar: :float, #between 0 and 1
    level: :varint,
    total_experience: :varint
  packet :play, 0x20, :entity_properties,
    entity_id: :varint,
    property_num: :int,
    properties: array(:property_num, [
      key: :string,
      value: :double,
      modifier_num: :varint,
      modifiers: array(:modifier_num, [
        uuid: :uuid,
        amount: :double,
        operation: :byte
      ])
    ])
  packet :play, 0x21, :chunk_data,
    chunk_x: :int,
    chunk_z: :int,
    continuous: :bool,
    section_mask: :u_short,
    chunk_data: :data

  defmodule ChunkData, do: defstruct [:blocks, :light, :skylight]

  defp write_block_types([block | rest], data) do
    write_block_types(rest, <<data::binary, block::little-unsigned-integer-2*8>>)
  end
  defp write_block_types([], data) do
    data
  end

  defp write_block_light([block | rest], data) do
    write_block_light(rest, <<data::bitstring, block::unsigned-integer-4>>)
  end
  defp write_block_light([], data) do
    data
  end

  defp write_biome_data([block | rest], data) do
    write_biome_data(rest, <<data::bitstring, block::unsigned-integer-8>>)
  end
  defp write_biome_data([], data) do
    data
  end

  packet :play, 0x23, :block_change,
    location: :position,
    block_id: :varint

  packet :play, 0x26, :map_chunk_bulk,
    sky_light_sent: :bool,
    chunk_column_count: :varint,
    chunk_metas: array(:chunk_column_count, [
      chunk_x: :int,
      chunk_z: :int,
      section_mask: :u_short]),
    chunk_data: :data
    #chunk_data: array(:chunk_column_count, {fn struct, :chunk_data -> #TODO: Implement decoding as well
    #  blocks = Enum.to_list(Enum.map(1..(16*16*16), fn _ -> 1 end))
    #  data = <<write_block_types(blocks, <<>>)::binary, write_block_light(blocks, <<>>)::binary>>
    #  <<data::binary, data::binary, data::binary, data::binary>>
    #end, nil})
    
  packet :play, 0x38, :player_list_item,
    action: :varint,
    element_num: :varint,
    players_add: exists_if(:action, 0, array(:element_num, [
      uuid: :uuid,
      name: :string,
      property_num: :varint,
      properties: array(:property_num, [
        name: :string,
        value: :string,
        has_signature: :bool,
        signature: exists_if(:has_signature, true, :string),
      ]),
      gamemode: :varint,
      ping: :varint,
      has_display_name: :bool,
      display_name: exists_if(:has_display_name, true, :string)
    ])),
    players_update_gamemode: exists_if(:action, 1, array(:element_num, [
      uuid: :uuid,
      gamemode: :varint
    ])),
    players_update_ping: exists_if(:action, 2, array(:element_num, [
      uuid: :uuid,
      ping: :varint
    ])),
    players_update_display_name: exists_if(:action, 3, [
      uuid: :uuid,
      has_display_name: :bool,
      display_name: exists_if(:has_display_name, true, :string)
    ]),
    players_remove: exists_if(:action, 4, array(:element_num, [
      uuid: :uuid
    ]))
    
  packet :play, 0x39, :player_abilities,
    flags: :byte_flags, #creative, flying, can_fly, godmode
    flying_speed: :float,
    walking_speed: :float

  packet :play, 0x40, :disconnect, reason: :chat

  use McProtocol.Packets.Macros.End
end
