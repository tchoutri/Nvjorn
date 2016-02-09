defmodule Nvjorn.Workers.FTP do
  use GenServer
  require Logger
  alias Nvjorn.Services.FTP, as: F

  @max_retries Application.get_env(:nvjorn, :ftp)[:max_retries]
  @interval Application.get_env(:nvjorn, :ftp)[:interval]
  @ibts Application.get_env(:nvjorn, :ftp)[:interval_between_two_sequences]

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

  def handle_info({:ded, %F{}=item}, state) do
      Logger.warn("[FTP] Host #{item.name} (#{item.host}) not responding…")
      {:noreply, state}
  end

  def handle_info({:alive, %F{}=item}, state) do
    Logger.info("[FTP] Host #{item.name} is alive! " <> IO.ANSI.magenta <> "( ◕‿◕)" <> IO.ANSI.reset)
    {:noreply, state}
  end

  def handle_info({:retry, %F{failure_count: @max_retries}=item}, state) do
    Logger.warn("[FTP] We lost all contact with " <> item.name <> ". Initialising photon torpedos launch.")
    send(self, {:ns, item})
    {:noreply, state}
  end

  def handle_info({:retry, %F{failure_count: failures}=item}, state) do
    :timer.sleep(@interval)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: failures + 1}) 
    end)
    {:noreply, state}
  end

  def handle_info({:ns, item}, state) do
    Logger.info("[FTP] Retrying in #{@ibts / 1000} seconds for " <> inspect item.name)
    :timer.sleep(@ibts)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: 0})
    end)
    {:noreply, state}
  end

  def spawn_probe(%F{}=item) do
    :poolboy.transaction(
      :ftp_pool,
        fn(worker) ->
          GenServer.call(worker, {:check, item})
        end, :infinity)
  end

  # Yeah, binaries as values suck for erlang functions.
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
    s   = struct(%F{}, map)
    Logger.debug("Transformed struct => " <> inspect s)
    s
  end

  def connect(%F{}=item) do
    Logger.debug("[FTP] Connecting to " <> inspect item.name)
    {:ok, pid} = :ftp.open(item.host, [{:port, item.port}])

    case :ftp.user(pid, item.user, item.password)  do
      {:error, reason} ->
        Logger.error(inspect reason)
        send(self, {:ded, item})
        send(self, {:retry, item})
      :ok ->
        Logger.debug "[FTP] Connected!"
        send(self, {:alive, item})
        send(self, {:ns, item})
    end
    :ftp.close(pid)
  end

  def handle_call({:check, %F{}=item}, _from, state) do
    item = convert_struct(item)
    Logger.info("[FTP] Monitoring " <> List.to_string(item.name))
    case parse_host(item.host) do
      {:ok, _addr} ->
        result = connect(item)
        {:reply, result, state}
      {:error, reason} ->
        Logger.error("[FTP] " <> reason)
        {:stop, :shutdown, :wtf, state}
    end
  end

  # Get the term. Try to parse the address. If you can't,
  # Check if it's a hostname and try to get an IP address out of it.
  # If you really can't do anything with it, stop the procedure.

  @spec parse_host(tuple()) :: {:ok, tuple()} | {:error, term()}
  @spec parse_host(list()) :: {:ok, tuple()} | {:error, term()}
  defp parse_host(host) when is_tuple(host) do
    Logger.debug("[FTP] Host is " <> inspect(host))
    case :inet.parse_address(host) do
      {:ok, ip} ->
        {:ok, ip}
      _         -> 
        {:error, "Could not parse “host” field."}
    end
  end

  defp parse_host(host) when is_list(host) do
    Logger.debug("[FTP] Host is " <> inspect(host))
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
