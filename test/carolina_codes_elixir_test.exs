defmodule CarolinaCodesElixirTest do
  use CarolinaCodesElixirWeb.ConnCase, async: false

  alias CarolinaCodesElixir.Catalog
  alias CarolinaCodesElixir.Db

  test "mix precommit and mise check include compiler, credo, sobelow, audit, and gitleaks" do
    mix = File.read!(Path.expand("../mix.exs", __DIR__))
    assert mix =~ "compile --warnings-as-errors"
    assert mix =~ "format --check-formatted"
    assert mix =~ "credo --strict"
    assert mix =~ "sobelow --exit --threshold high --skip"
    assert mix =~ "deps.audit"
    assert mix =~ "preferred_envs: [precommit: :test]"
    assert mix =~ "gitleaks detect --source ."

    mise = File.read!(Path.expand("../mise.toml", __DIR__))
    assert mise =~ "gitleaks"
    assert mise =~ "mix precommit"
    assert mise =~ "gitleaks detect --source ."
  end

  test "test env uses fake catalog so mix test does not need Postgres" do
    assert Application.get_env(:carolina_codes_elixir, :query_fn) ==
             {CarolinaCodesElixir.FakeCatalog, :query}

    assert Application.get_env(:carolina_codes_elixir, :connect_fn) ==
             {CarolinaCodesElixir.FakeCatalog, :connect}

    src = File.read!(Path.expand("../config/test.exs", __DIR__))
    assert src =~ "CarolinaCodesElixir.FakeCatalog"
    refute src =~ "Postgrex.start_link"
  end

  test "HTTP is served through Phoenix Endpoint, not a Plug.Router Bandit child" do
    refute File.exists?(Path.expand("../lib/carolina_codes_elixir/router.ex", __DIR__))
    assert Code.ensure_loaded?(CarolinaCodesElixirWeb.Endpoint)
    assert Code.ensure_loaded?(CarolinaCodesElixirWeb.Router)

    src = File.read!(Path.expand("../lib/carolina_codes_elixir/application.ex", __DIR__))
    refute src =~ "{Bandit,"
    refute src =~ "plug: CarolinaCodesElixir.Router"
    assert src =~ "CarolinaCodesElixirWeb.Endpoint"

    adapter =
      Application.get_env(:carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint)[:adapter]

    assert adapter == Bandit.PhoenixAdapter
  end

  test "listen host is IPv6 dual-stack" do
    assert CarolinaCodesElixir.listen_host() == "::"
    assert tuple_size(CarolinaCodesElixir.listen_ip()) == 8

    src = File.read!(Path.expand("../config/runtime.exs", __DIR__))
    assert src =~ "ipv6_v6only: false"
    assert src =~ "CarolinaCodesElixir.listen_ip()"
    refute src =~ "ip: {0, 0, 0, 0}"

    http = Application.get_env(:carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint)[:http]
    assert http[:ip] == CarolinaCodesElixir.listen_ip()
    assert get_in(http, [:thousand_island_options, :transport_options, :ipv6_v6only]) == false
  end

  test "register-once does not open Postgres or run catalog SQL" do
    src = File.read!(Path.expand("../lib/carolina_codes_elixir/register.ex", __DIR__))
    refute src =~ "Db.query"
    refute src =~ "Postgrex."
    refute src =~ "open_pool"
    refute src =~ "Catalog."
  end

  test "register uses inet6 for Fly 6PN hosts" do
    internal = "http://carolina-codes.internal:8080/internal/api-endpoints/register"
    opts = CarolinaCodesElixir.Register.req_opts(internal)
    assert opts[:inet6] == true
    assert opts[:retry] == false

    local =
      CarolinaCodesElixir.Register.req_opts(
        "http://127.0.0.1:4000/internal/api-endpoints/register"
      )

    refute local[:inet6]

    src = File.read!(Path.expand("../lib/carolina_codes_elixir/register.ex", __DIR__))
    assert src =~ ~s[String.contains?(to_string(url), ".internal:")]
    assert src =~ "Keyword.put(opts, :inet6, true)"
    assert src =~ "req_opts(url)"
  end

  test "production image is Debian with RELEASE_DISTRIBUTION=none" do
    docker = File.read!(Path.expand("../Dockerfile", __DIR__))
    assert docker =~ "debian"
    assert docker =~ "RELEASE_DISTRIBUTION=none"
    assert docker =~ "en_US.UTF-8"
    assert docker =~ "PHX_SERVER"
    assert docker =~ "/app/bin/server"
    refute docker =~ "alpine"
    refute docker =~ "apk add"

    fly = File.read!(Path.expand("../fly.toml", __DIR__))
    assert fly =~ ~s(app = "carolina-codes-elixir")
    assert fly =~ ~s(PORT = "8080")
    assert fly =~ ~s(CAROLINA_URL = "http://carolina-codes.internal:8080")
    assert fly =~ ~s(PUBLIC_BASE_URL = "https://carolina-codes-elixir.fly.dev")
    assert fly =~ ~s(path = "/health")
    assert fly =~ ~s(RELEASE_DISTRIBUTION = "none")
    assert fly =~ ~s(PHX_SERVER = "true")
    assert fly =~ ~s(auto_stop_machines = "suspend")
    assert fly =~ "auto_start_machines = true"
    refute fly =~ ~s(auto_stop_machines = "stop")
  end

  test "release vm args disable scheduler busy-wait for bin/server" do
    vm = File.read!(Path.expand("../rel/vm.args.eex", __DIR__))
    assert vm =~ "+sbwt none"
    assert vm =~ "+sbwtdcpu none"
    assert vm =~ "+sbwtdio none"

    server = File.read!(Path.expand("../rel/overlays/bin/server", __DIR__))
    assert server =~ "exec ./carolina_codes_elixir start"
    refute server =~ "ELIXIR_ERL_OPTIONS"
  end

  test "endpoint listens before the pool and the pool is not eight connections" do
    ids =
      Enum.map(CarolinaCodesElixir.Application.children(), fn
        {mod, _opts} -> mod
        mod -> mod
      end)

    endpoint = Enum.find_index(ids, &(&1 == CarolinaCodesElixirWeb.Endpoint))
    db = Enum.find_index(ids, &(&1 == CarolinaCodesElixir.Db))
    assert is_integer(endpoint) and is_integer(db)
    assert endpoint < db

    opts = Db.parse_url("postgres://postgres:postgres@127.0.0.1:1/carolina_dev")
    assert opts[:pool_size] >= 1
    assert opts[:pool_size] < 8
    assert Db.conn_opts()[:pool_size] == opts[:pool_size]

    http = Application.get_env(:carolina_codes_elixir, CarolinaCodesElixirWeb.Endpoint)[:http]
    acceptors = get_in(http, [:thousand_island_options, :num_acceptors])
    assert is_integer(acceptors) and acceptors >= 1 and acceptors < 100
  end

  test "credo strict includes lib and test and excludes deps and _build" do
    {config, _} = Code.eval_file(Path.expand("../.credo.exs", __DIR__))
    files = hd(config[:configs])[:files]
    assert "lib/" in files[:included]
    assert "test/" in files[:included]

    refute Enum.any?(files[:included], fn path ->
             String.contains?(path, "deps") or String.contains?(path, "_build")
           end)

    excluded = Enum.map(files[:excluded], &inspect/1)
    assert Enum.any?(excluded, &String.contains?(&1, "_build"))
    assert Enum.any?(excluded, &String.contains?(&1, "deps"))
  end

  test "/health is ok JSON and does not run SQL or connect", %{conn: conn} do
    sql = Db.sql_count()
    connects = Db.connect_count()
    conn = get(conn, ~p"/health")
    assert conn.status == 200
    body = json_response(conn, 200)
    assert body["ok"] == true or body["status"] == "ok"
    assert Db.sql_count() == sql
    assert Db.connect_count() == connects
  end

  test "GET / returns Phoenix identity and polyglot framework header", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert conn.status == 200
    body = json_response(conn, 200)
    assert body["language"] == "Elixir"
    assert body["framework"] == "Phoenix"
    refute body["framework"] == "Bandit"
    assert is_list(body["endpoints"])
    assert get_resp_header(conn, "x-polyglot-language") == ["Elixir"]
    assert get_resp_header(conn, "x-polyglot-framework") == ["Phoenix"]
  end

  test "year speaker listing SQL is bounded, years DESC, pool reused", %{conn: conn} do
    boot = Db.connect_count()
    Db.set_sql_count(0)

    conn = get(conn, ~p"/v1/speakers?year=2026")
    body = json_response(conn, 200)
    speakers = body["data"] || []
    sql = Db.sql_count()
    n = length(speakers)

    IO.puts(
      :stderr,
      "year list status=#{conn.status} sql=#{sql} speakers=#{n} connects=#{Db.connect_count()}"
    )

    assert conn.status == 200
    assert n >= 3
    assert sql > 0
    assert sql < 2 * n
    assert sql <= 4
    assert_years_desc(speakers, "handler")
    assert Enum.any?(speakers, fn sp -> is_list(sp["languages"]) and is_list(sp["topics"]) end)
    assert Db.connect_count() == boot

    rows = Catalog.list_speakers(2026)
    assert_years_desc(rows, "list_speakers")

    Db.set_sql_count(0)
    conn2 = get(build_conn(), ~p"/v1/speakers?year=2026")
    assert conn2.status == 200
    assert Db.connect_count() == boot
  end

  test "unknown speaker slug is 404", %{conn: conn} do
    conn = get(conn, ~p"/v1/speakers/not-a-real-slug-zzz")
    assert conn.status == 404
    assert json_response(conn, 404)["error"] == "not_found"
  end

  test "year speaker detail includes talks languages", %{conn: conn} do
    conn = get(conn, ~p"/v1/speakers/2026/diana-pham")
    assert conn.status == 200
    data = json_response(conn, 200)["data"]
    assert data["slug"] == "diana-pham"
    assert is_list(data["talks"])
    assert is_list(data["languages"]) or Enum.any?(data["talks"], &is_list(&1["languages"]))
  end

  test "year sponsors include tier", %{conn: conn} do
    conn = get(conn, ~p"/v1/sponsors?year=2026")
    assert conn.status == 200
    data = json_response(conn, 200)["data"]
    assert match?([_ | _], data)
    assert Enum.any?(data, &is_binary(&1["tier"]))
  end

  test "unknown sponsor slug is 404", %{conn: conn} do
    conn = get(conn, ~p"/v1/sponsors/not-a-real-sponsor-zzz")
    assert conn.status == 404
    assert json_response(conn, 404)["error"] == "not_found"
  end

  test "GET /v1/years returns data list", %{conn: conn} do
    conn = get(conn, ~p"/v1/years")
    assert conn.status == 200
    data = json_response(conn, 200)["data"]
    assert is_list(data)
    assert Enum.any?(data, &(&1["year"] == 2026))
  end

  test "every endpoints/0 route succeeds through the Phoenix router" do
    for spec <- CarolinaCodesElixir.endpoints() do
      for path <- success_paths(spec) do
        conn = get(build_conn(), path)
        body = json_response(conn, 200)

        cond do
          spec["path"] == "/health" ->
            assert body["ok"] == true

          spec["path"] == "/" ->
            assert body["language"] == "Elixir"
            assert body["framework"] == "Phoenix"

          true ->
            assert is_list(body["data"]) or is_map(body["data"])
        end
      end
    end
  end

  test "catalog queries increment sql counters without persistent_term writes" do
    Db.set_sql_count(0)
    connects = Db.connect_count()

    {speakers, puts} = traced_puts(fn -> Catalog.list_speakers(2026) end)
    sql = Db.sql_count()

    assert length(speakers) >= 3
    assert sql > 0
    assert sql <= 4
    assert sql < 2 * length(speakers)
    assert Db.connect_count() == connects
    assert puts == []
    assert_years_desc(speakers, "traced year list")

    conn = get(build_conn(), "/v1/speakers?year=2026")
    body = json_response(conn, 200)
    assert length(body["data"]) == length(speakers)
    assert Db.connect_count() == connects
  end

  defp success_paths(%{"path" => "/v1/speakers"}),
    do: ["/v1/speakers", "/v1/speakers?year=2026"]

  defp success_paths(%{"path" => "/v1/sponsors"}),
    do: ["/v1/sponsors", "/v1/sponsors?year=2026"]

  defp success_paths(%{"path" => "/v1/speakers/:slug"}), do: ["/v1/speakers/diana-pham"]

  defp success_paths(%{"path" => "/v1/speakers/:year/:slug"}),
    do: ["/v1/speakers/2026/diana-pham"]

  defp success_paths(%{"path" => "/v1/sponsors/:slug"}), do: ["/v1/sponsors/flywheel"]

  defp success_paths(%{"path" => "/v1/sponsors/:year/:slug"}),
    do: ["/v1/sponsors/2026/flywheel"]

  defp success_paths(%{"path" => path}), do: [path]

  defp traced_puts(fun) do
    parent = self()

    pid =
      spawn(fn ->
        receive do
          :go -> send(parent, {self(), :result, fun.()})
        end
      end)

    :erlang.trace_pattern({:persistent_term, :put, 2}, true, [:local])
    :erlang.trace(pid, true, [:call])

    try do
      send(pid, :go)

      receive do
        {^pid, :result, result} -> {result, collect_puts([])}
      after
        5_000 -> flunk("traced catalog call timed out")
      end
    after
      if Process.alive?(pid), do: :erlang.trace(pid, false, [:call])
      :erlang.trace_pattern({:persistent_term, :put, 2}, false, [:local])
    end
  end

  defp collect_puts(acc) do
    receive do
      {:trace, _, :call, {:persistent_term, :put, args}} -> collect_puts([args | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp assert_years_desc(speakers, label) do
    multi_year = Enum.filter(speakers, fn sp -> match?([_, _ | _], sp["years"] || []) end)
    assert multi_year != [], "#{label} expected a speaker with >=2 years"

    Enum.each(multi_year, fn sp ->
      years = sp["years"]

      assert years == Enum.sort(years, :desc),
             "#{label} years not DESC for #{sp["slug"]}: #{inspect(years)}"
    end)
  end
end
