import Config

config :carolina_codes_elixir,
  port: String.to_integer(System.get_env("PORT") || "4015"),
  database_url:
    System.get_env("DATABASE_URL") || "postgres://postgres:postgres@127.0.0.1:5432/carolina_dev"
