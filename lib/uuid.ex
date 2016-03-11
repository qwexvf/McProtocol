defmodule McProtocol.UUID do
  defstruct bin: nil, hex: nil

  def uuid4 do
    from_hex(String.replace(UUID.uuid4, "-", ""))
  end

  @spec from_hex(str) :: %McProtocol.UUID{} | :error when str: binary
  def from_hex(str) when byte_size(str) == 32 do
    case Base.decode16(str, case: :lower) do
      {:ok, bin} -> %McProtocol.UUID { hex: str, bin: bin }
      _ -> :error
    end
  end
  def from_hex(str) when byte_size(str) == 36 do
    from_hex(String.replace(str, "-", ","))
  end

  @spec from_bin(bin) :: %McProtocol.UUID{} when bin: binary
  def from_bin(bin) when byte_size(bin) == 16 do
    %McProtocol.UUID {
      bin: bin,
      hex: Base.encode16(bin, case: :lower)
    }
  end

  def hex(%McProtocol.UUID{hex: hex}), do: hex
  def hex_hyphen(%McProtocol.UUID{hex: hex}), do: hyphenize_string(hex)
  def bin(%McProtocol.UUID{bin: bin}), do: bin

  def hyphenize_string(uuid) when byte_size(uuid) == 32 do
    String.to_char_list(uuid)
    |> List.insert_at(20, "-") |> List.insert_at(16, "-") |> List.insert_at(12, "-") |> List.insert_at(8, "-")
    |> List.to_string
  end
end
