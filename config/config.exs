import Config

config :carolina_codes_elixir,
  generators: [timestamp_type: :utc_datetime],
  listen_ip: {0, 0, 0, 0, 0, 0, 0, 0}

config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CarolinaCodesElixirWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CarolinaCodesElixir.PubSub

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
