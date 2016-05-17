defmodule McProtocol.Acceptor.ProtocolState do

  defmodule Connection do
    defstruct control: nil, reader: nil, writer: nil, write: nil

    def write_packet(%__MODULE__{write: write}, struct) do
      write.(struct)
    end
  end

  defstruct user: nil, connection: nil, config: %{online_mode: false}

end
