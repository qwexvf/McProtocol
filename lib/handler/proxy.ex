defmodule McProtocol.Handler.Proxy do
  use McProtocol.Handler

  defmodule State do
    defstruct [
      socket: nil,
      read_state: nil,
      write_state: nil,
    ]

    def set_encryption(state, encr = %McProtocol.Crypto.Transport.CryptData{}) do
      %{state |
        read_state: McProtocol.Transport.Read.set_encryption(state.read_state, encr),
        write_state: McProtocol.Transport.Write.set_encryption(state.write_state, encr),
       }
    end
    def set_compression(state, compr) do
      %{state |
        read_state: McProtocol.Transport.Read.set_compression(state.read_state, compr),
        write_state: McProtocol.Transport.Write.set_compression(state.write_state, compr),
       }
    end
  end

  defmodule Args do
    defstruct [
      host: nil,
      port: nil,
    ]
  end

  def enter(args, %{direction: :Client, mode: :Play}) do
  end
end
