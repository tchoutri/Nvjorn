defmodule Nvjorn do
  use Application

  alias Nvjorn.Services.HTTP, as: H
  alias Nvjorn.Services.ICMP, as: I
  alias Nvjorn.Services.FTP,  as: F

  require Logger

  def start(_type, _args) do
    spawn(fn -> all_monitors end)
    Nvjorn.Supervisor.start_link
  end

  def all_monitors do
    Logger.info(IO.ANSI.green <> "Initializing" <> IO.ANSI.reset)
    #:timer.sleep(2500) # Dirty Trick to wait for the supervisor to start everything
    :gproc.await({:n, :l, Nvjorn.Supervisor})
    Logger.info(IO.ANSI.green <> "Starting Probes" <> IO.ANSI.reset)
    monitor_http
    monitor_icmp
    monitor_ftp
  end

  def monitor_http,  do: monitor(:http, HTTP, H)
  def monitor_icmp,  do: monitor(:icmp, ICMP, I)
  def monitor_ftp,   do: monitor(:ftp,  FTP, F)

  def monitor(conf, module, struct) do
    targets = Application.get_env(:nvjorn, conf)[:file] |> YamlElixir.read_from_file
    ##### HERE   BE   DRAGONS #####
    ##### SAFE ZONE ENDS HERE #####
    f_targets = Enum.concat(for item <- targets, do: Map.values(item))                # We only want to content of each "item".
      |> Enum.map(fn(string_map) ->
           for {key, val} <- string_map, into: %{}, do: {String.to_atom(key), val}    # Now, we turn those string-based keys into atom-based keys,
         end)                                                                         # so they fit in the Struct.
      |> Enum.map(fn(map) -> struct(struct, map) end)                                 # We translate all those new maps into structs,
    worker = Module.concat(Nvjorn.Worker, module)
    worker.dispatch(f_targets)                                                        # that we can happily send to our worker.
  end
end
