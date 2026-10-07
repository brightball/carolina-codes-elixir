defmodule CarolinaCodesElixir.DocsContractTest do
  @moduledoc false
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @agents Path.join(@root, "AGENTS.md")
  @readme Path.join(@root, "README.md")
  @memory Path.join(@root, "MEMORY.md")
  @decisions Path.join(@root, "DECISIONS.md")
  @mix Path.join(@root, "mix.exs")
  @mise Path.join(@root, "mise.toml")

  @docs [@agents, @readme, @memory, @decisions]

  @routes [
    "GET /health",
    "GET /",
    "GET /v1/years",
    "GET /v1/speakers",
    "GET /v1/speakers/{slug}",
    "GET /v1/speakers/{year}/{slug}",
    "GET /v1/sponsors",
    "GET /v1/sponsors/{slug}",
    "GET /v1/sponsors/{year}/{slug}"
  ]

  @views [
    "v1_speakers",
    "v1_sponsors",
    "v1_years",
    "v1_talks",
    "v1_sponsorships",
    "v1_year_sponsors",
    "v1_year_speakers"
  ]

  test "AGENTS.md keeps the starter contract and the drifts this API shipped" do
    agents = File.read!(@agents)

    for view <- @views, do: assert(agents =~ view)

    assert agents =~ "never Ash resource tables"
    assert agents =~ "Do not query Ash tables"
    assert agents =~ "application/vnd.api+json"
    assert agents =~ "Ash JSON:API"

    for route <- @routes, do: assert(agents =~ route)

    assert agents =~ "no heartbeat"
    assert agents =~ "log and continue"
    assert agents =~ "log and keep serving"
    assert agents =~ "does not hit the database"

    assert agents =~ "Bandit.PhoenixAdapter"
    assert agents =~ "not a raw `Plug.Router`"
    assert agents =~ "does not use LiveView, Ecto, Ash, or an asset pipeline"
    assert agents =~ "priv/api/openapi.yaml"
    assert agents =~ "priv/api/AGENTS.md"
    assert agents =~ "Default listen port is 4015"
    assert agents =~ "Handler tests do not need Postgres"
    assert agents =~ "Outbound HTTP is Req only"
    assert agents =~ "mix precommit"
    assert agents =~ "mise run check"
    assert agents =~ "FakeCatalog"

    assert agents =~ "MEMORY.md"
    assert agents =~ "DECISIONS.md"
    assert agents =~ "Update memory in place"
    assert agents =~ "superseded"

    refute agents =~ "test_catalog.py"
    refute agents =~ "Postgres 18"
    refute agents =~ "docker-compose"
    refute agents =~ "forkable starter"
    refute agents =~ "does not ship a finished API"
    refute agents =~ "src/"
    refute agents =~ "db/02_views.sql"
  end

  test "MEMORY.md states the current facts" do
    memory = File.read!(@memory)

    assert memory =~ "Phoenix"
    assert memory =~ "Bandit.PhoenixAdapter"
    assert memory =~ "Not a raw `Plug.Router`"
    assert memory =~ "Outbound HTTP is Req only"
    assert memory =~ "v1_speakers"
    assert memory =~ "FakeCatalog"
    assert memory =~ "do not need Postgres"
    assert memory =~ "runs once on boot"
    assert memory =~ "No heartbeat"
    assert memory =~ "mix precommit"
    assert memory =~ "mise run check"
    assert memory =~ "Update a fact in place"
  end

  test "DECISIONS.md records status, context, choice, and consequence" do
    text = File.read!(@decisions)

    parts =
      text
      |> String.split(~r/^## D\d+\. /m)
      |> Enum.drop(1)

    refute parts == []

    for part <- parts do
      assert part =~ "- **Status:** "
      assert part =~ "- **Context:** "
      assert part =~ "- **Choice:** "
      assert part =~ "- **Consequence:** "
      assert Regex.match?(~r/\*\*Status:\*\* (accepted|superseded)\b/, part)
    end

    statuses =
      Regex.scan(~r/\*\*Status:\*\* (accepted|superseded)\b/, text)
      |> Enum.map(fn [_, status] -> status end)

    assert "accepted" in statuses
    assert "superseded" in statuses
    refute Enum.all?(statuses, &(&1 == "superseded"))
  end

  test "README versions match mise.toml and mix.exs" do
    readme = File.read!(@readme)
    mise = File.read!(@mise)
    mix = File.read!(@mix)

    elixir_pin = capture!(mise, ~r/^elixir = "([^"]+)"/m)
    otp_pin = capture!(mise, ~r/^erlang = "([^"]+)"/m)
    elixir_req = capture!(mix, ~r/elixir: "([^"]+)"/)

    assert line_has?(readme, "Elixir", elixir_pin)
    assert line_has?(readme, "Elixir", elixir_req)
    assert line_has?(readme, "Erlang/OTP", otp_pin)

    for {label, dep} <- [
          {"Phoenix", "phoenix"},
          {"Bandit", "bandit"},
          {"Req", "req"},
          {"Jason", "jason"},
          {"Postgrex", "postgrex"},
          {"Credo", "credo"},
          {"Sobelow", "sobelow"},
          {"mix_audit", "mix_audit"},
          {"Mint", "mint"}
        ] do
      version = capture!(mix, ~r/\{:#{dep}, "([^"]+)"/)
      assert line_has?(readme, label, version), "#{label} #{version} missing from README"
    end

    refute readme =~ "CRaC"
    refute readme =~ "crac"
  end

  test "agent docs contain no private markers" do
    for path <- @docs do
      text = File.read!(path)
      refute text =~ ".ts.net", path
      refute text =~ "zebra-hydra", path
      refute text =~ "SECRET_KEY_BASE", path
      refute text =~ "fly.dev", path
      refute text =~ "ghp_"
      refute text =~ "github_pat_"
      refute_register_tokens!(text)
      refute_bearer_tokens!(text)
      refute_database_urls!(text)
      refute text =~ ~r/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
    end
  end

  defp line_has?(text, name, version) do
    text
    |> String.split("\n")
    |> Enum.any?(fn line ->
      String.contains?(line, name) and String.contains?(line, version)
    end)
  end

  defp refute_register_tokens!(text) do
    for [_, token] <- Regex.scan(~r/POLYGLOT_REGISTER_TOKEN=([A-Za-z0-9_.{}-]+)/, text) do
      assert token == "dev" or String.starts_with?(token, "{"), token
    end
  end

  defp refute_bearer_tokens!(text) do
    for [_, token] <- Regex.scan(~r/Authorization:\s*Bearer\s+(\S+)/, text) do
      assert token == "dev" or String.starts_with?(token, "{"), token
    end
  end

  defp refute_database_urls!(text) do
    for [url] <- Regex.scan(~r/postgres:\/\/\S+/, text) do
      assert String.starts_with?(url, "postgres://postgres:postgres@127.0.0.1"), url
    end
  end

  defp capture!(text, regex) do
    case Regex.run(regex, text) do
      [_, value] ->
        value

      _ ->
        flunk("pattern #{inspect(regex)} did not match")
    end
  end
end
