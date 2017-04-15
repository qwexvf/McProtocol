defmodule McProtocol.EntityMetaTest do
  use ExUnit.Case, async: true
  alias McProtocol.EntityMeta

  test "type idx conversion" do
    assert EntityMeta.type_idx(:varint) == 1
    assert EntityMeta.idx_type(1) == :varint
    assert EntityMeta.type_idx(:position) == 8
    assert EntityMeta.idx_type(8) == :position
  end
end
