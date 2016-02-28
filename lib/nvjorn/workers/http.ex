defmodule Nvjorn.Worker.HTTP do
  use GenServer
  require Logger
  alias Nvjorn.Services.HTTP, as: H

  @verbz ["GET", "POST", "PUT", "HEAD", "DELETE", "PATCH"]
  @max_retries Application.get_env(:nvjorn, :http)[:max_retries]
  @interval Application.get_env(:nvjorn, :http)[:interval]
  @ibts Application.get_env(:nvjorn, :icmp)[:interval_between_two_sequences]

  @behaviour Worker

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

  defp spawn_probe(%H{}=item) do
    :poolboy.transaction(
      :http_pool,
        fn(worker)->
        GenServer.call(worker, {:check, item})
      end, :infinity)
  end

  defp connect({verb, path, %H{}=item}) do
    Logger.debug(inspect item)
    prefix = if item.ssl == "true" do
      "https://"
    else
      "http://"
    end
    url = prefix <> item.host <> ":#{item.port}" <> path
    Logger.debug(item.name <> " ~> " <> url)
    case HTTPoison.request(verb, url) do
      {:error, _error} ->
        send(self, {:ded, item})
        send(self, {:retry, item})
      {:ok, _result} -> 
        send(self, {:alive, item})
        send(self, {:ns, item})
    end
  end

  defp fail_miserably(:unknown_verb, verb), do: raise(ArgumentError, message: "Unknown HTTP verb \"#{verb}\" :-(")

  def handle_call({:check, %H{}=item}, _from, state) do
    Logger.info("[HTTP] Monitoring #{item.name}")
    [verb, path, _] = item.request |> String.split(" ")

    result = case verb do
      verb when verb in @verbz ->
        {verb |> String.downcase |> String.to_atom, path, item} |> connect
      _ ->
        fail_miserably(:unknown_verb, verb)
    end
      {:reply, result, state}
  end

  def handle_info({:ded, %H{}=item}, state) do
    Logger.warn("[HTTP] Host #{item.name} (#{item.host}:#{item.port}) not responding…")
    {:noreply, state}
  end

  def handle_info({:alive, %H{}=item}, state) do
    Logger.info("[HTTP] Host " <> IO.ANSI.cyan  <> item.name <> IO.ANSI.reset <> " is alive! " <> IO.ANSI.magenta <> "( ◕‿◕)" <> IO.ANSI.reset)
    {:noreply, state}
  end

  def handle_info({:retry, %H{failure_count: @max_retries}=item}, state) do
    Logger.warn("[HTTP] We lost all contact with " <> item.name <> ". Initialising photon torpedos launch.")
    send(self, {:ns, item})
    {:noreply, state}  
  end

  def handle_info({:retry, %H{failure_count: failures}=item}, state) do
    :timer.sleep(@interval)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: failures + 1}) 
    end)
    {:noreply, state}
  end

  def handle_info({:ns, item}, state) do
    Logger.info("[HTTP] Retrying in #{@ibts / 1000} seconds for #{item.name}")
    :timer.sleep(@ibts)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: 0}) 
    end)
    {:noreply, state}
  end
end
