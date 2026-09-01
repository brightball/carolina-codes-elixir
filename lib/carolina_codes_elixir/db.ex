defmodule CarolinaCodesElixir.Db do
  @moduledoc false

  @pool __MODULE__

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link do
    inc_connect()

    case connect_fn() do
      fun when is_function(fun, 0) ->
        fun.()

      _ ->
        Postgrex.start_link(Keyword.put(conn_opts(), :name, @pool))
    end
  end

  def pool, do: @pool

  def query(sql, params \\ []) do
    inc_sql()

    case query_fn() do
      fun when is_function(fun, 2) ->
        fun.(sql, params)

      _ ->
        result = Postgrex.query!(@pool, sql, params)
        rows_to_maps(result)
    end
  end

  def query_one(sql, params \\ []) do
    case query(sql, params) do
      [row | _] -> row
      _ -> nil
    end
  end

  def sql_count, do: :persistent_term.get({__MODULE__, :sql}, 0)
  def connect_count, do: :persistent_term.get({__MODULE__, :connect}, 0)

  def reset_counts do
    :persistent_term.put({__MODULE__, :sql}, 0)
    :persistent_term.put({__MODULE__, :connect}, 0)
  end

  def set_sql_count(n), do: :persistent_term.put({__MODULE__, :sql}, n)
  def set_connect_count(n), do: :persistent_term.put({__MODULE__, :connect}, n)

  def set_query_fn(fun), do: Application.put_env(:carolina_codes_elixir, :query_fn, fun)
  def set_connect_fn(fun), do: Application.put_env(:carolina_codes_elixir, :connect_fn, fun)

  def conn_opts do
    url =
      Application.get_env(:carolina_codes_elixir, :database_url) ||
        System.get_env("DATABASE_URL") ||
        "postgres://postgres:postgres@127.0.0.1:5432/carolina_dev"

    parse_url(url)
  end

  def parse_url(url) do
    uri = URI.parse(url)
    {user, pass} = userinfo(uri.userinfo)
    db = uri.path |> to_string() |> String.trim_leading("/") |> String.split("?") |> hd()

    [
      hostname: uri.host || "127.0.0.1",
      port: uri.port || 5432,
      username: user,
      password: pass,
      database: db,
      pool_size: 8,
      ssl: false,
      socket_options: socket_options(url)
    ]
  end

  defp socket_options(url) do
    if String.contains?(url, "flycast") or String.contains?(url, ".internal") or
         String.contains?(url, ".fly.io") do
      [:inet6]
    else
      []
    end
  end

  defp userinfo(nil), do: {"postgres", "postgres"}

  defp userinfo(info) do
    case String.split(info, ":", parts: 2) do
      [user] -> {URI.decode(user), "postgres"}
      [user, pass] -> {URI.decode(user), URI.decode(pass)}
    end
  end

  defp rows_to_maps(%Postgrex.Result{columns: cols, rows: rows}) do
    Enum.map(rows, fn row ->
      cols
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  defp inc_sql do
    :persistent_term.put({__MODULE__, :sql}, sql_count() + 1)
  end

  defp inc_connect do
    :persistent_term.put({__MODULE__, :connect}, connect_count() + 1)
  end

  defp query_fn, do: Application.get_env(:carolina_codes_elixir, :query_fn)
  defp connect_fn, do: Application.get_env(:carolina_codes_elixir, :connect_fn)
end
