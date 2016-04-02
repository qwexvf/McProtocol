defmodule McProtocol.EntityMetaTest do
  use ExUnit.Case, async: true
  alias McProtocol.EntityMeta

  test "type idx conversion" do
    assert EntityMeta.type_idx(:short) == 1
    assert EntityMeta.idx_type(1) == :short
    assert EntityMeta.type_idx(:pos) == 6
    assert EntityMeta.idx_type(6) == :pos
  end
end
