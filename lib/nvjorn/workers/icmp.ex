defmodule Nvjorn.Workers.ICMP do
  use GenServer
  require Logger
  alias Nvjorn.Services.ICMP, as: I

  @max_retries 10
  @interval 500

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def dispatch(targets) do
    Enum.each(
      targets,
      fn(item) ->
        spawn(fn() -> spawn_probe(item) end)
      end)
  end

  defp parse_struct(item) do
    if is_list item.host do
      :inet.parse_address(item.host)
    else
      :inet.getaddr(item.host, item.inet)
    end
  end

  def handle_call({:check, %I{}=item}, _from, state) do
    Logger.info("Monitoring #{item.name}")
    if is_binary(item.host) and is_binary(item.inet) do
      s_inet = item.inet
      s_host = item.host
      item = %{item | inet: String.to_atom(s_inet), host: String.to_char_list(s_host)}
    end
    case parse_struct(item) do
      {:ok, _addr} ->
        result = connect(item)
        {:reply, result, state}
      {:error, :einval} ->
        {:stop, :shutdown, :lol, state}
    end
  end

  defp spawn_probe(%I{}=item) do
    Logger.debug(inspect(item))
    :poolboy.transaction(
      :icmp_pool,
        fn(worker)->
        GenServer.call(worker, {:check, item})
      end, :infinity)
  end

  defp connect(%I{}=item) do
    Logger.debug("Connecting to " <> item.name)
    [result] = :gen_icmp.ping(item.host, [item.inet])
    case elem(result, 0) do
      :error ->
        send(self, {:ded, item})
        send(self, {:retry, item})
      :ok ->
        send(self, {:alive, item})
    end
  end

  def handle_info({:ded, %I{}=item}, state) do
    Logger.warn("Host #{item.name} (#{item.host}) not responding…")
    {:noreply, state}
  end

  def handle_info({:alive, %I{}=item}, state) do
    Logger.info("Host #{item.name} is alive!")
    {:noreply, state}
  end

  def handle_info({:retry, %I{failure_count: @max_retries}=item}, state) do
    Logger.warn("We lost all contact with " <> item.name <> ". Initialising photon torpedos launch.")
    {:noreply, state}  
  end

  def handle_info({:retry, %I{failure_count: failures}=item}, state) do
    :timer.sleep(@interval)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: failures + 1}) 
    end)
    {:noreply, state}
  end

end
