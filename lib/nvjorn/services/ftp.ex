defmodule Nvjorn.Services.FTP do
  defstruct host: "",
            name: "",
            user: "",
            password: "",
            port: 21,
            failure_count: 0
end
