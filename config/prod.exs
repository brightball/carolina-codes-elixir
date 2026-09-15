import Config

# Fly terminates TLS and forwards HTTP with x-forwarded-proto. Exclude the
# health check so the internal HTTP probe is not redirected.
config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      hosts: ["localhost", "127.0.0.1"],
      paths: ["/health"]
    ]
  ]

config :logger, level: :info
