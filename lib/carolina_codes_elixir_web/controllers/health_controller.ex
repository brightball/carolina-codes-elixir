defmodule CarolinaCodesElixirWeb.HealthController do
  use CarolinaCodesElixirWeb, :controller

  def show(conn, _params) do
    json(conn, %{ok: true})
  end
end
