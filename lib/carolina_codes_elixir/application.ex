defmodule CarolinaCodesElixir.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CarolinaCodesElixir.Db,
      {Phoenix.PubSub, name: CarolinaCodesElixir.PubSub},
      CarolinaCodesElixirWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: CarolinaCodesElixir.Supervisor]
    result = Supervisor.start_link(children, opts)
    Task.start(fn -> CarolinaCodesElixir.Register.run() end)
    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    CarolinaCodesElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
