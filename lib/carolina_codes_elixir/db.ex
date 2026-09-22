defmodule CarolinaCodesElixir.Db do
  @moduledoc false

  @pool __MODULE__
  @counter_key {__MODULE__, :counters}
  @sql_idx 1
  @connect_idx 2
  # Eight eager sockets stall a 256MB shared-cpu boot before /health is useful.
  @pool_size 2

  def boot_counters do
    case :persistent_term.get(@counter_key, nil) do
      nil ->
        ref = :counters.new(2, [:write_concurrency])
        :persistent_term.put(@counter_key, ref)
        :ok

      _ref ->
        :ok
    end
  end

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def start_link do
    boot_counters()
    inc_connect()

    case call_hook(connect_fn(), []) do
      :default ->
        Postgrex.start_link(Keyword.put(conn_opts(), :name, @pool))

      result ->
        result
    end
  end

  def pool, do: @pool

  def query(sql, params \\ []) do
    inc_sql()

    case call_hook(query_fn(), [sql, params]) do
      :default ->
        result = Postgrex.query!(@pool, sql, params)
        rows_to_maps(result)

      result ->
        result
    end
  end

  def query_one(sql, params \\ []) do
    case query(sql, params) do
      [row | _] -> row
      _ -> nil
    end
  end

  def sql_count, do: :counters.get(counters(), @sql_idx)
  def connect_count, do: :counters.get(counters(), @connect_idx)

  def reset_counts do
    :counters.put(counters(), @sql_idx, 0)
    :counters.put(counters(), @connect_idx, 0)
  end

  def set_sql_count(n), do: :counters.put(counters(), @sql_idx, n)
  def set_connect_count(n), do: :counters.put(counters(), @connect_idx, n)

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
      pool_size: @pool_size,
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

  defp inc_sql, do: :counters.add(counters(), @sql_idx, 1)

  defp inc_connect, do: :counters.add(counters(), @connect_idx, 1)

  defp counters, do: :persistent_term.get(@counter_key)

  defp query_fn, do: Application.get_env(:carolina_codes_elixir, :query_fn)
  defp connect_fn, do: Application.get_env(:carolina_codes_elixir, :connect_fn)

  defp call_hook(fun, args) when is_function(fun) and is_list(args), do: apply(fun, args)

  defp call_hook({mod, fun}, args) when is_atom(mod) and is_atom(fun) do
    apply(mod, fun, args)
  end

  defp call_hook(_other, _args), do: :default
end
