defmodule McProtocol.ClosedError do
  defexception []
  def message(_exception) do
    "Connection closed"
  end
end
