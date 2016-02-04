defmodule Nvjorn.Workers.HTTP do
  use GenServer
  require Logger
  alias Nvjorn.Services.HTTP, as: H

  @verbz ["GET", "POST", "PUT", "HEAD", "DELETE", "PATCH"]
  @max_retries 10
  @interval 5000

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
    url = "http://" <> item.host <> ":#{item.port}" <> path
    Logger.debug(item.name <> " ~> " <> url)
    case HTTPoison.request(verb, url) do
      {:ok, result} -> 
        send(self, {:alive, item})
      {:error, error} ->
        send(self, {:ded, item})
        send(self, {:retry, item})
    end
  end

  def handle_call({:check, %H{}=item}, _from, state) do
    Logger.info("Monitoring #{item.name}")
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
    Logger.warn("Host #{item.name} (#{item.host}:#{item.port}) not responding…")
    {:noreply, state}
  end

  def handle_info({:alive, %H{}=item}, state) do
    Logger.info("Host #{item.name} is alive!")
    {:noreply, state}
  end

  def handle_info({:retry, %H{failure_count: @max_retries}=item}, state) do
    Logger.warn("We lost all contact with " <> item.name <> ". Initialising photon torpedos launch.")
    {:noreply, state}  
  end

  def handle_info({:retry, %H{failure_count: failures}=item}, state) do
    :timer.sleep(@interval)
    spawn(fn() ->
      spawn_probe(%{item | failure_count: failures + 1}) 
    end)
    {:noreply, state}
  end

  defp fail_miserably(:unknown_verb, verb), do: raise(ArgumentError, message: "Unknown HTTP verb \"#{verb}\" :-(")

end
