defmodule CarolinaCodesElixir.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        CarolinaCodesElixir.Db
      ] ++ http_children()

    opts = [strategy: :one_for_one, name: CarolinaCodesElixir.Supervisor]
    result = Supervisor.start_link(children, opts)
    Task.start(fn -> CarolinaCodesElixir.Register.run() end)
    result
  end

  def http_children do
    if Application.get_env(:carolina_codes_elixir, :start_http, true) do
      port = Application.get_env(:carolina_codes_elixir, :port) || 4015

      [
        {Bandit,
         plug: CarolinaCodesElixir.Router,
         scheme: :http,
         port: port,
         ip: CarolinaCodesElixir.listen_ip(),
         thousand_island_options: [
           transport_options: [ipv6_v6only: false]
         ]}
      ]
    else
      []
    end
  end
end
