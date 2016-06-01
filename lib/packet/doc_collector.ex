defmodule McProtocol.Packet.DocCollector do
  use GenServer

  # Client

  def start_link(path \\ "./_build/PACKETS.md") do
    GenServer.start_link(__MODULE__, path)
  end

  def collect_packet(pid, data) do
    GenServer.call(pid, {:collect_packet, data})
  end

  def finish(pid) do
    GenServer.call(pid, :finish)
  end

  # Server

  def init(path) do
    {:ok, %{path: path, packets: []}}
  end

  def handle_call({:collect_packet, data}, _from, state) do
    state = %{state | packets: [data | state.packets]}
    {:reply, :ok, state}
  end

  def handle_call(:finish, _from, state) do
    packets_sorted = Enum.sort(
      state.packets,
      &(Atom.to_string(&1.module) < Atom.to_string(&2.module)))

    out_text = Enum.map(packets_sorted, fn packet ->
      "Elixir." <> module = Atom.to_string(packet.module)
      [
        "## #{module}\n",
        "```\n",
        "#{inspect(packet.structure, pretty: true)}\n",
        "```\n",
      ]
    end)

    file = File.open!(state.path, [:write, encoding: :utf8])
    :ok = IO.write(file, out_text)
    :ok = File.close(file)

    {:stop, :normal, :ok, state}
  end

end
