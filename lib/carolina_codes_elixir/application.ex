defmodule CarolinaCodesElixir.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Counters exist before the listener accepts. The pool starts after it,
    # so /health does not wait on Postgres.
    CarolinaCodesElixir.Db.boot_counters()

    opts = [strategy: :one_for_one, name: CarolinaCodesElixir.Supervisor]
    result = Supervisor.start_link(children(), opts)
    Task.start(fn -> CarolinaCodesElixir.Register.run() end)
    result
  end

  def children do
    [
      {Phoenix.PubSub, name: CarolinaCodesElixir.PubSub},
      CarolinaCodesElixirWeb.Endpoint,
      CarolinaCodesElixir.Db
    ]
  end

  @impl true
  def config_change(changed, _new, removed) do
    CarolinaCodesElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
