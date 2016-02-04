defmodule Nvjorn do
  use Application
  alias Nvjorn.Services.HTTP, as: H

  def start(_type, _args) do
    Nvjorn.Supervisor.start_link
  end

  def monitor_http do
    targets = Application.get_env(:nvjorn, :http) |> YamlElixir.read_from_file
    ##### HERE   BE   DRAGONS #####
    ##### SAFE ZONE ENDS HERE #####
    f_targets = Enum.concat(for item <- targets, do: Map.values(item))                # We only want to content of each "item".
      |> Enum.map(fn(string_map) ->
           for {key, val} <- string_map, into: %{}, do: {String.to_atom(key), val}    # Now, we turn those string-based keys into atom-based keys,
         end)                                                                         # so they fit in the Struct.
      |> Enum.map(fn(map) -> struct(H, map) end)                                      # We translate all those new maps into structs,
    Nvjorn.Workers.HTTP.dispatch(f_targets)                                 # that we can happily send to our worker.
  end
  # Just so you know, the original one-liner looks like:
  #  f_targets = Enum.concat(for item <- targets, do: Map.values(item)) |> Enum.map(fn(string_map) -> for {key, val} <- string_map, into: %{}, do: {String.to_atom(key), val} end) |> Enum.map(fn(map) -> struct(H, map) end)
  # Don't thank me.
end
