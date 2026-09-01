defmodule CarolinaCodesElixirTest do
  use ExUnit.Case, async: false
  import Plug.Test

  alias CarolinaCodesElixir.Catalog
  alias CarolinaCodesElixir.Db
  alias CarolinaCodesElixir.Router

  @opts Router.init([])

  defp get(path) do
    conn(:get, path)
    |> Router.call(@opts)
  end

  defp json(conn) do
    Jason.decode!(conn.resp_body)
  end

  test "listen host is IPv6 dual-stack" do
    assert CarolinaCodesElixir.listen_host() == "::"
    assert tuple_size(CarolinaCodesElixir.listen_ip()) == 8
    src = File.read!(Path.expand("../lib/carolina_codes_elixir/application.ex", __DIR__))
    assert src =~ "ipv6_v6only: false"
    assert src =~ "CarolinaCodesElixir.listen_ip()"
    refute src =~ "ip: {0, 0, 0, 0}"
  end

  test "register-once does not open Postgres or run catalog SQL" do
    src = File.read!(Path.expand("../lib/carolina_codes_elixir/register.ex", __DIR__))
    refute src =~ "Db.query"
    refute src =~ "Postgrex."
    refute src =~ "open_pool"
    refute src =~ "Catalog."
  end

  test "/health is ok JSON and does not run SQL or connect" do
    sql = Db.sql_count()
    connects = Db.connect_count()
    conn = get("/health")
    assert conn.status == 200
    body = json(conn)
    assert body["ok"] == true or body["status"] == "ok"
    assert Db.sql_count() == sql
    assert Db.connect_count() == connects
  end

  test "GET / returns identity" do
    conn = get("/")
    assert conn.status == 200
    body = json(conn)
    assert body["language"] == "Elixir"
    assert body["framework"] == "Bandit"
    assert is_list(body["endpoints"])
  end

  test "year speaker listing SQL is bounded, years DESC, pool reused" do
    boot = Db.connect_count()
    Db.set_sql_count(0)

    conn = get("/v1/speakers?year=2026")
    body = json(conn)
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
    conn2 = get("/v1/speakers?year=2026")
    assert conn2.status == 200
    assert Db.connect_count() == boot
  end

  test "unknown speaker slug is 404" do
    conn = get("/v1/speakers/not-a-real-slug-zzz")
    assert conn.status == 404
    assert json(conn)["error"] == "not_found"
  end

  test "year speaker detail includes talks languages" do
    conn = get("/v1/speakers/2026/diana-pham")
    assert conn.status == 200
    data = json(conn)["data"]
    assert data["slug"] == "diana-pham"
    assert is_list(data["talks"])
    assert is_list(data["languages"]) or Enum.any?(data["talks"], &is_list(&1["languages"]))
  end

  test "year sponsors include tier" do
    conn = get("/v1/sponsors?year=2026")
    assert conn.status == 200
    data = json(conn)["data"]
    assert length(data) >= 1
    assert Enum.any?(data, &is_binary(&1["tier"]))
  end

  test "unknown sponsor slug is 404" do
    conn = get("/v1/sponsors/not-a-real-sponsor-zzz")
    assert conn.status == 404
  end

  defp assert_years_desc(speakers, label) do
    found_multi =
      Enum.reduce(speakers, false, fn sp, acc ->
        years = sp["years"] || []

        if length(years) < 2 do
          acc
        else
          Enum.reduce(Enum.chunk_every(years, 2, 1, :discard), true, fn [a, b], ok ->
            assert a >= b, "#{label} years not DESC for #{sp["slug"]}: #{inspect(years)}"
            ok
          end)

          true
        end
      end)

    assert found_multi, "#{label} expected a speaker with >=2 years"
  end
end
