defmodule McProtocol.Acceptor.ProtocolState do

  defmodule Connection do
    defstruct control: nil, read: nil, write: nil

    def write_packet(%__MODULE__{write: write}, struct) do
      GenServer.cast(write, {:write_struct, struct})
    end
  end

  defstruct user: nil, connection: nil, config: %{online_mode: false}

end
