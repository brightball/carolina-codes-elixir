import Config

# Releases only listen when PHX_SERVER is set. `mix phx.server` enables the
# endpoint itself. Docker/Fly set PHX_SERVER so `bin/start` actually binds.
if System.get_env("PHX_SERVER") do
  config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint, server: true
end

port = String.to_integer(System.get_env("PORT") || "4015")

config :carolina_codes_elixir,
  port: port,
  database_url:
    System.get_env("DATABASE_URL") || "postgres://postgres:postgres@127.0.0.1:5432/carolina_dev"

# Dual-stack IPv6 (`::` with ipv6_v6only: false) so Fly 6PN and local IPv4 both work.
# listen_ip/0 is the IPv6 any-address; do not bind {0, 0, 0, 0} (IPv4-only).
config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
  http: [
    ip: CarolinaCodesElixir.listen_ip(),
    port: port,
    thousand_island_options: [
      # Default 100 acceptors is wasted work on a 1 shared CPU.
      num_acceptors: 20,
      transport_options: [ipv6_v6only: false]
    ]
  ]

if config_env() == :prod do
  host = System.get_env("PHX_HOST") || "carolina-codes-elixir.fly.dev"

  # Sessionless JSON API: generate a boot-local key if Fly has no SECRET_KEY_BASE.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(48))

  config :carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    secret_key_base: secret_key_base
end
