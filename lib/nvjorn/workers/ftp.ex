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

  def spawn_probe(%F{}=item) do
    :poolboy.transaction(
      :ftp_pool,
        fn(worker) ->
          GenServer.call(worker, {:check, item})
        end, :infinity)
  end

  def connect(%F{}=item) do
    Logger.debug("[FTP] Connecting to " <> item.name)
    ip   = item.host |> String.to_char_list
    port = item.port
    user = item.user |> String.to_char_list
    passwd  = item.password |> String.to_char_list
    {:ok, pid} = :ftp.open(ip, [{:port, port}])

    case :ftp.user(pid, user, passwd)  do
      {:error, reason} ->
        Logger.debug(inspect reason)
        send(self, {:def, item})
        send(self, {:retry, item})
      :ok ->
        send(self, {:alive, item})
        send(self, {:ns, item})
    end
    :ftp.close(pid)
  end

  defp parse_struct(item) do
    if is_list item.host do
      :inet.parse_address(item.host)
    else
      case :inet.getaddr(item.host, :inet) do
      {:ok, ip} ->
        {:ok, ip}
      {:error, :nxdomain} ->
      {:error, }
      end
    end
  end


  def handle_call({:check, %F{}=item}, _from, state) do
    Logger.info("[FTP] Monitoring " <> item.name)
    case parse_struct(item) do
      {:ok, _addr} ->
        result = connect(item)
        {:ok, result, state}
      {:error, :einval} ->
        {:stop, :shutdown, :meh, state}
      {:error, :nxdomain} ->
        Logger.error("[FTP] NXDOMAIN on #{item.host}")
        {:stop, :shutdown, :nxdomain, state}
      foo ->
        Logger.error("[FTP] Could not catch error: #{inspect(foo)}")
        {:stop, :shutdown, :wtf, state}
    end
  end

  def handle_info({:ded, %F{}=item}, state) do
      Logger.warn("[FTP] Host #{item.name} (#{item.host}) not responding…")
      {:noreply, state}
  end

  def handle_info({:alive, %F{}=item}, state) do
    Logger.info("[FTP] Host #{item.name} is alive!")
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
    Logger.info("[FTP] Retrying in #{@ibts / 1000} seconds for " <> item.name)
    :timer.sleep(@ibts)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: 0})
    end)
    {:noreply, state}
  end
end

