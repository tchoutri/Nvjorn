defmodule Nvjorn.Workers.ICMP do
  use GenServer
  require Logger
  alias Nvjorn.Services.ICMP, as: I

  @max_retries Application.get_env(:nvjorn, :icmp)[:max_retries]
  @interval Application.get_env(:nvjorn, :icmp)[:interval]
  @ibts Application.get_env(:nvjorn, :icmp)[:interval_between_two_sequences]

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

  def convert_struct(item) do
    [_|keys] = Map.keys(item)
    [_|values] =
    for i <- Map.values(item) do
      if is_binary(i) do
        String.to_char_list(i)
      else
        i
      end
    end
    map = Enum.zip(keys, values) |> Enum.into(%{})
    s   = struct(%I{}, map)
    Logger.debug("Transformed struct => " <> inspect s)
    s
  end

  def handle_call({:check, %I{}=item}, _from, state) do
    item = convert_struct(item)
    Logger.info("[ICMP] Monitoring #{item.name}")
    case parse_host(item.host) do
      {:ok, _addr} ->
        result = connect(item)
        {:reply, result, state}
      {:error, reason} ->
        Logger.error("[ICMP] " <> reason)
        {:stop, :shutdown, :meh, state}
      foo ->
        Logger.error("[ICMP] Could not catch error: #{inspect foo} for #{inspect item.name}")
        {:stop, :shutdown, :wtf, state}
    end
  end

  defp spawn_probe(%I{}=item) do
    :poolboy.transaction(
      :icmp_pool,
        fn(worker)->
        GenServer.call(worker, {:check, item})
      end, :infinity)
  end

  def multi_connect(%I{}=item) do
    Enum.each(10..0,
      fn(n) -> connect(item)
    end)
  end
  def connect(%I{}=item) do
    Logger.debug("[ICMP] Connecting to " <> inspect item.name)
    [result] = :gen_icmp.ping(item.host, [item.inet])
    Logger.debug(inspect(result))
    case elem(result, 0) do
      :error ->
        send(self, {:ded, item})
        send(self, {:retry, item})
      :ok ->
        send(self, {:alive, item})
        send(self, {:ns, item})
    end
  end

  def handle_info({:ded, %I{}=item}, state) do
    Logger.warn("[ICMP] Host #{inspect item.name} (#{inspect item.host}) not responding…")
    {:noreply, state}
  end

  def handle_info({:alive, %I{}=item}, state) do
    Logger.info("[ICMP] Host " <> IO.ANSI.cyan  <> inspect(item.name) <> IO.ANSI.reset <> " is alive! " <> IO.ANSI.magenta <> "( ◕‿◕)" <> IO.ANSI.reset)
    {:noreply, state}
  end

  def handle_info({:retry, %I{failure_count: @max_retries}=item}, state) do
    Logger.warn("[ICMP] We lost all contact with " <> item.name <> ". Initialising photon torpedos launch.")
    send(self, {:ns, item})
    {:noreply, state}
  end

  def handle_info({:retry, %I{failure_count: failures}=item}, state) do
    :timer.sleep(@interval)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: failures + 1})
    end)
    {:noreply, state}
  end

  def handle_info({:ns, item}, state) do
    Logger.info("[ICMP] Retrying in #{@ibts / 1000} seconds for #{item.name}")
    :timer.sleep(@ibts)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: 0}) 
    end)
    {:noreply, state}
  end

  @spec parse_host(tuple()) :: {:ok, tuple()} | {:error, term()}
  @spec parse_host(list()) :: {:ok, tuple()} | {:error, term()}

  defp parse_host(host) when is_tuple(host) do
    Logger.debug("[ICMP] Host is " <> inspect(host))
    case :inet.parse_address(host) do
      {:ok, ip} ->
        {:ok, ip}
      _         -> 
        {:error, "Could not parse “host” field."}
    end
  end

  defp parse_host(host) when is_binary(host) do
    parse_host(String.to_charlist(host))
  end

  defp parse_host(host) when is_list(host) do
    Logger.debug("[ICMP] Host is " <> inspect(host))
    case :inet.getaddr(host, :inet) do
      {:ok, ip} ->
        {:ok, ip}
      {:error, :eafnosupport} ->
        :inet.getaddr(host, :inet6)
      _ ->
        {:error, "Could not parse “host” field."}
    end
  end
end
