defmodule McProtocol.Acceptor.SimpleAcceptor do
  @moduledoc false
  require Logger

  @tcp_listen_options [:binary, packet: :raw, active: false, reuseaddr: true]

  def accept(port, accept_fun, socket_transferred_fun \\ fn _, _ -> nil end) do
    {:ok, listen} = :gen_tcp.listen(port, @tcp_listen_options)
    Logger.info("Listening on port #{port}")
    accept_loop(listen, accept_fun, socket_transferred_fun)
  end

  defp accept_loop(listen, accept_fun, socket_transferred_fun) do
    IO.puts "start accept_loop"
    {:ok, socket} = :gen_tcp.accept(listen)
    {:ok, pid} = accept_fun.(socket)
    :ok = :gen_tcp.controlling_process(socket, pid)
    socket_transferred_fun.(pid, socket)
    accept_loop(listen, accept_fun, socket_transferred_fun)
  end
end
