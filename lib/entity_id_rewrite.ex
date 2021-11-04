defmodule McProtocol.EntityIdRewrite.Util do
  def rewrite_info(module) when is_atom(module), do: {module, [:entity_id]}
  def rewrite_info({module, field}), do: {module, field}
end

defmodule McProtocol.EntityIdRewrite do
  alias McProtocol.Packet.{Client, Server}

  # Simple rewrites
  rewrites = [
    Server.Play.SpawnEntity,
    Server.Play.SpawnEntityExperienceOrb,
    Server.Play.SpawnEntityWeather,
    Server.Play.SpawnEntityLiving,
    Server.Play.SpawnEntityPainting,
    Server.Play.NamedEntitySpawn,
    Server.Play.Animation,
    Server.Play.BlockBreakAnimation,
    Server.Play.EntityStatus,
    Server.Play.EntityMove,
    Server.Play.EntityMoveLook,
    Server.Play.EntityLook,
    Server.Play.Entity,
    Server.Play.Bed,
    Server.Play.RemoveEntityEffect,
    Server.Play.EntityHeadRotation,
    {Server.Play.Camera, [:camera_id]},
    Server.Play.EntityMetadata,
    {Server.Play.AttachEntity, [:entity_id, :vehicle_id]},
    Server.Play.EntityVelocity,
    Server.Play.EntityEquipment,
    {Server.Play.Collect, [:collected_entity_id, :collector_entity_id]},
    Server.Play.EntityTeleport,
    Server.Play.EntityUpdateAttributes,
    Server.Play.EntityEffect,
    {Client.Play.UseEntity, [:target]},
    Client.Play.EntityAction
  ]

  def rewrite_eid(eid, {eid, replace}), do: replace
  def rewrite_eid(eid, {replace, eid}), do: replace
  def rewrite_eid(eid, {_, _}), do: eid

  def rewrite(packet = %Server.Play.EntityDestroy{}, ids) do
    %{
      packet
      | entity_ids:
          Enum.map(packet.entity_ids, fn
            eid -> rewrite_eid(eid, ids)
          end)
    }
  end

  def rewrite(packet = %Server.Play.CombatEvent{event: 1}, ids) do
    %{packet | entity_id: rewrite_eid(packet.entity_id, ids)}
  end

  def rewrite(packet = %Server.Play.CombatEvent{event: 2}, ids) do
    %{
      packet
      | entity_id: rewrite_eid(packet.entity_id, ids),
        player_id: rewrite_eid(packet.player_id, ids)
    }
  end

  def rewrite(packet = %Server.Play.SetPassengers{}, ids) do
    %{
      packet
      | entity_id: rewrite_eid(packet.entity_id, ids),
        passengers:
          Enum.map(packet.passengers, fn
            eid -> rewrite_eid(eid, ids)
          end)
    }
  end

  for rewrite_data <- rewrites do
    {module, fields} = McProtocol.EntityIdRewrite.Util.rewrite_info(rewrite_data)

    packet_var = Macro.var(:packet, __MODULE__)
    ids_var = Macro.var(:ids, __MODULE__)

    fields =
      Enum.map(fields, fn
        field ->
          {field,
           quote do
             rewrite_eid(
               unquote(packet_var).unquote(field),
               unquote(ids_var)
             )
           end}
      end)

    def rewrite(unquote(packet_var) = %unquote(module){}, unquote(ids_var)) do
      %{unquote(packet_var) | unquote_splicing(fields)}
    end
  end

  def rewrite(packet, _) do
    packet
  end
end
