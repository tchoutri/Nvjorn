defmodule Nvjorn.Supervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

    def init([]) do
    Logger.info(IO.ANSI.green <> "Supervisor started." <> IO.ANSI.reset)

    http_pool = [
      name: {:local, :http_pool},
      worker_module: Nvjorn.Workers.HTTP,
      size: 50,
      max_overflow: 1
    ]
    
    icmp_pool = [
      name: {:local, :icmp_pool},
      worker_module: Nvjorn.Workers.ICMP,
      size: 50,
      max_overflow: 1
    ]

    ftp_pool = [
      name: {:local, :ftp_pool},
      worker_module: Nvjorn.Workers.FTP,
      size: 50,
      max_overflow: 1
    ]

    children = [
      :poolboy.child_spec(:http_pool, http_pool, []),
      :poolboy.child_spec(:icmp_pool, icmp_pool, []),
      :poolboy.child_spec(:ftp_pool,  ftp_pool,  []),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
