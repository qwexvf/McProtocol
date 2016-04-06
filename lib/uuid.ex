defmodule McProtocol.UUID do

  @moduledoc """
  Utilities for working with UUIDs in Minecraft.

  Can deal with both hyphenated, unhyphenated and binary UUIDs.
  """

  @type t :: %__MODULE__{}

  defstruct bin: nil, hex: nil

  def uuid4 do
    from_hex(String.replace(UUID.uuid4, "-", ""))
  end

  @spec from_hex(str) :: t | :error when str: binary
  def from_hex(hex_data) when byte_size(hex_data) == 32 do
    case Base.decode16(hex_data, case: :lower) do
      {:ok, bin_data} -> %McProtocol.UUID { hex: hex_data, bin: bin_data }
      _ -> :error
    end
  end
  def from_hex(str) when byte_size(str) == 36 do
    from_hex(String.replace(str, "-", ","))
  end

  @spec from_bin(bin) :: t when bin: binary
  def from_bin(bin_data) when byte_size(bin_data) == 16 do
    %McProtocol.UUID {
      bin: bin_data,
      hex: Base.encode16(bin_data, case: :lower)
    }
  end

  def hex(%McProtocol.UUID{hex: hex_data}), do: hex_data
  def hex_hyphen(%McProtocol.UUID{hex: hex_data}), do: hyphenize_string(hex_data)
  def bin(%McProtocol.UUID{bin: bin_data}), do: bin_data

  defp hyphenize_string(uuid) when byte_size(uuid) == 32 do
    uuid
    |> String.to_char_list
    |> List.insert_at(20, "-") |> List.insert_at(16, "-") |> List.insert_at(12, "-") |> List.insert_at(8, "-")
    |> List.to_string
  end
end
