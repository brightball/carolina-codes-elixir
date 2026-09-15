import Config

config :carolina_codes_elixir,
  query_fn: {CarolinaCodesElixir.FakeCatalog, :query},
  connect_fn: {CarolinaCodesElixir.FakeCatalog, :connect}

config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
  http: [port: 4015],
  secret_key_base: "test-carolina-codes-elixir-secret-key-base-not-for-production-use-x",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix, sort_verified_routes_query_params: true
