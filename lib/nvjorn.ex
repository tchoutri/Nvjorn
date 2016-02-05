defmodule Nvjorn do
  use Application
  alias Nvjorn.Services.HTTP, as: H
  alias Nvjorn.Services.ICMP, as: I

  def start(_type, _args) do
    Nvjorn.Supervisor.start_link
  end

  def monitor_http, do: monitor(:http, HTTP, H)
  def monitor_icmp,  do: monitor(:icmp, ICMP, I)

  def monitor(conf, module, struct) do
    targets = Application.get_env(:nvjorn, conf) |> YamlElixir.read_from_file
    ##### HERE   BE   DRAGONS #####
    ##### SAFE ZONE ENDS HERE #####
    f_targets = Enum.concat(for item <- targets, do: Map.values(item))                # We only want to content of each "item".
      |> Enum.map(fn(string_map) ->
           for {key, val} <- string_map, into: %{}, do: {String.to_atom(key), val}    # Now, we turn those string-based keys into atom-based keys,
         end)                                                                         # so they fit in the Struct.
      |> Enum.map(fn(map) -> struct(struct, map) end)                                      # We translate all those new maps into structs,
    worker = Module.concat(Nvjorn.Workers, module)
    worker.dispatch(f_targets)                                                        # that we can happily send to our worker.
  end
  # Just so you know, the original one-liner looks like:
  #  f_targets = Enum.concat(for item <- targets, do: Map.values(item)) |> Enum.map(fn(string_map) -> for {key, val} <- string_map, into: %{}, do: {String.to_atom(key), val} end) |> Enum.map(fn(map) -> struct(H, map) end)
  # Don't thank me.
end
