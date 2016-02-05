defmodule Nvjorn.Services.SSH do
  defstruct host: "",
            name: "",
            port: nil,
            user: "",
            key: "",
            command: "uptime",
            failure_count: 0

end
