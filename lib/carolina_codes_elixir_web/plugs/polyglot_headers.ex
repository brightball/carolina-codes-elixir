defmodule CarolinaCodesElixirWeb.Plugs.PolyglotHeaders do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-polyglot-language", CarolinaCodesElixir.language())
    |> put_resp_header("x-polyglot-framework", CarolinaCodesElixir.framework())
  end
end
