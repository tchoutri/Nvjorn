use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :nvjorn,
  http: [file: "priv/http.yml",
         max_retries: 10,
         interval: 5000,
         interval_between_two_sequences: 60000
        ],

  icmp: [file: "priv/icmp.yml",
          max_retries: 10,
          interval: 500,
          interval_between_two_sequences: 30000
        ],

  ftp: [file: "priv/ftp.yml",
        max_retries: 10,
        interval: 10000,
        interval_between_two_sequences: 45000
      ]
