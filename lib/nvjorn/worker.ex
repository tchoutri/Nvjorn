defmodule Worker do

  @callback dispatch([struct()]) :: any()

  @callback spawn_probe(struct()) :: any()

  @callback connect(struct()) :: :ok | :error

end
