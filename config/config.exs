import Config

config :carolina_codes_elixir,
  start_http: true,
  listen_ip: {0, 0, 0, 0, 0, 0, 0, 0}

import_config "#{config_env()}.exs"
