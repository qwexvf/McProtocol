defmodule McProtocol.Acceptor.SimpleAcceptor do
  require Logger

  @tcp_listen_options [:binary, packet: :raw, active: false, reuseaddr: true]

  def accept(port, accept_fun) do
    {:ok, listen} = :gen_tcp.listen(port, @tcp_listen_options)
    Logger.info("Listening on port #{port}")
    accept_loop(listen, accept_fun)
  end

  defp accept_loop(listen, accept_fun) do
    {:ok, socket} = :gen_tcp.accept(listen)
    {:ok, pid} = accept_fun.(socket)
    :ok = :gen_tcp.controlling_process(socket, pid)
    accept_loop(listen, accept_fun)
  end

end
