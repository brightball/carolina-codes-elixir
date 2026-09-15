defmodule CarolinaCodesElixirWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint CarolinaCodesElixirWeb.Endpoint

      use CarolinaCodesElixirWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
