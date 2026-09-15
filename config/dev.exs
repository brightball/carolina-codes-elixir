import Config

config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-carolina-codes-elixir-secret-key-base-not-for-production-use-xx"

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
