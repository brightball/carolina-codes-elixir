defmodule CarolinaCodesElixirWeb.IdentityController do
  use CarolinaCodesElixirWeb, :controller

  def show(conn, _params) do
    json(conn, CarolinaCodesElixir.identity())
  end
end
