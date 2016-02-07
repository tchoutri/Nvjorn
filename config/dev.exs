use Mix.Config

config :nvjorn,
  http: [file: "priv/http.yml",
         max_retries: 10,
         interval: 5000,
         interval_between_two_sequences: 60000
        ],

  icmp:  [file: "priv/icmp.yml",
          max_retries: 10,
          interval: 500,
          interval_between_two_sequences: 30000
         ]
