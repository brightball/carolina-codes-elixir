defmodule CarolinaCodesElixir.GiteaPrecommitJobsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  @mix_exs Path.expand("../../mix.exs", __DIR__)
  @mise Path.expand("../../mise.toml", __DIR__)
  @workflow Path.expand("../../.gitea/workflows/precommit.yml", __DIR__)

  @clone_cmd ~s[git clone --depth 1 --no-checkout "https://x-access-token:${token}@${host}/${GITHUB_REPOSITORY}" .]
  @restore_extract "mix local.hex --force"
  @cold_apt "apt-get update -qq && apt-get install -y --no-install-recommends git build-essential ca-certificates"
  @gitleaks_cmd "gitleaks detect --source . --verbose"

  test "mix precommit and mise check include compiler, credo, sobelow, audit, test, and gitleaks" do
    mix = File.read!(@mix_exs)
    assert mix =~ "compile --warnings-as-errors"
    assert mix =~ "format --check-formatted"
    assert mix =~ "credo --strict"
    assert mix =~ "sobelow --exit --threshold high --skip"
    assert mix =~ "deps.audit"
    assert mix =~ "preferred_envs: [precommit: :test]"
    assert mix =~ @gitleaks_cmd

    checks = precommit_alias_entries(mix)
    assert "test" in checks
    assert Enum.any?(checks, &String.contains?(&1, @gitleaks_cmd))

    mise = File.read!(@mise)
    assert mise =~ "gitleaks"
    assert mise =~ "mix precommit"
    assert mise =~ "gitleaks detect --source ."
  end

  test "Gitea workflow has one job per mix precommit alias check plus a prep job" do
    mix = File.read!(@mix_exs)
    workflow = File.read!(@workflow)

    checks = precommit_alias_entries(mix)
    refute checks == [], "mix.exs precommit alias is empty"

    refute Enum.any?(checks, &String.contains?(&1, "dialyzer")),
           "Dialyzer must not be in precommit"

    jobs = workflow_jobs(workflow)
    job_names = Enum.map(jobs, &elem(&1, 0))

    assert "prep" in job_names
    assert "gitleaks" in job_names

    assert length(jobs) == length(checks) + 1,
           "expected prep + #{length(checks)} check jobs, got #{inspect(job_names)}"

    refute Regex.match?(~r/^\s+- run: mix precommit\s*$/m, workflow)
    refute String.contains?(workflow, "actions/checkout")

    for entry <- checks do
      mix_cmd = mix_check(entry)

      matching =
        Enum.filter(jobs, fn {_name, body} -> job_runs_check?(body, mix_cmd) end)

      assert length(matching) == 1,
             "#{mix_cmd} must be the check in exactly one job, got #{inspect(Enum.map(matching, &elem(&1, 0)))}"
    end
  end

  test "Gitea workflow does not set init.defaultBranch on every job" do
    workflow = File.read!(@workflow)
    refute String.contains?(workflow, "git config --global init.defaultBranch master")
  end

  test "Gitea workflow does not git init" do
    workflow = File.read!(@workflow)
    refute Regex.match?(~r/^\s*git init\b/m, workflow)
  end

  test "prep and gitleaks check out the SHA with the job token" do
    workflow = File.read!(@workflow)
    jobs = Map.new(workflow_jobs(workflow))

    assert workflow =~ ~r/GITHUB_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}/,
           "job token must be passed into the workflow so container git fetch can auth"

    for name <- ["prep", "gitleaks"] do
      body = Map.fetch!(jobs, name)

      assert String.contains?(body, @clone_cmd),
             "#{name} must clone the job workspace without git init"

      assert String.contains?(body, ~s[git fetch --depth 1 origin "${GITHUB_SHA}"]),
             "#{name} must fetch the SHA under test"

      assert String.contains?(body, "missing job token for git fetch"),
             "#{name} must fail closed if the job token is missing"
    end
  end

  test "Bookworm check jobs restore the prep workspace instead of a cold apt+clone+deps.get" do
    workflow = File.read!(@workflow)
    jobs = workflow_jobs(workflow)
    restore_jobs = Enum.reject(jobs, fn {name, _} -> name in ["prep", "gitleaks"] end)
    refute restore_jobs == []

    for {name, body} <- restore_jobs do
      assert String.contains?(body, "needs: prep"),
             "#{name} must wait for prep"

      assert String.contains?(body, "actions/download-artifact@v3"),
             "#{name} must download the prep artifact"

      assert String.contains?(body, "name: prep-workspace"),
             "#{name} must restore prep-workspace"

      assert String.contains?(body, "prep-workspace.tar.gz"),
             "#{name} must unpack the prep workspace"

      assert String.contains?(body, @restore_extract),
             "#{name} must install Hex in the fresh hexpm container"

      assert String.contains?(body, "nodejs"),
             "#{name} must install nodejs so the artifact action can run in hexpm"

      refute String.contains?(body, "git build-essential"),
             "#{name} must not repeat the prep cold-start apt-get"

      refute String.contains?(body, "build-essential"),
             "#{name} must not install a compiler toolchain"

      refute String.contains?(body, @clone_cmd),
             "#{name} must not clone; restore the prep workspace"

      refute String.contains?(body, "mix deps.get"),
             "#{name} must not mix deps.get; restore deps from prep"
    end
  end

  test "prep packs a Bookworm workspace artifact after checkout, deps.get, and compile" do
    jobs = Map.new(workflow_jobs(File.read!(@workflow)))
    prep = Map.fetch!(jobs, "prep")

    assert String.contains?(prep, @cold_apt)
    assert String.contains?(prep, @clone_cmd)
    assert String.contains?(prep, "mix deps.get")
    assert String.contains?(prep, "mix compile")
    refute String.contains?(prep, "mix compile --warnings-as-errors")
    assert String.contains?(prep, "nodejs")
    assert String.contains?(prep, "tar -czf /tmp/prep-workspace.tar.gz")

    assert String.contains?(prep, "--exclude=./.git"),
           "must not exclude deps/*/.git of git Hex deps"

    refute String.contains?(prep, "--exclude=.git")
    assert String.contains?(prep, "mv /tmp/prep-workspace.tar.gz prep-workspace.tar.gz")
    assert String.contains?(prep, "actions/upload-artifact@v3")
    assert String.contains?(prep, "name: prep-workspace")
    refute String.contains?(prep, "needs: prep")
  end

  test "test job restores prep and does not require CMS Postgres" do
    jobs = Map.new(workflow_jobs(File.read!(@workflow)))
    test = Map.fetch!(jobs, "test")

    assert String.contains?(test, "debian-bookworm")
    assert String.contains?(test, "needs: prep")
    assert String.contains?(test, "actions/download-artifact")
    assert String.contains?(test, "mix test")
    refute String.contains?(test, @clone_cmd)
    refute String.contains?(test, "mix deps.get")
    refute String.contains?(test, "image: postgres")
  end

  test "compile job force-recompiles so warnings-as-errors is not a no-op on restored _build" do
    jobs = Map.new(workflow_jobs(File.read!(@workflow)))
    compile = Map.fetch!(jobs, "compile")
    prep = Map.fetch!(jobs, "prep")

    assert String.contains?(compile, "mix compile --force --warnings-as-errors")
    refute Regex.match?(~r/^\s+- run: mix compile --warnings-as-errors\s*$/m, compile)

    assert String.contains?(prep, "mix compile")
    refute String.contains?(prep, "mix compile --force")
    refute String.contains?(prep, "mix compile --warnings-as-errors")
  end

  test "gitleaks is its own Gitea job and is not a Mix task" do
    jobs = Map.new(workflow_jobs(File.read!(@workflow)))
    gitleaks = Map.fetch!(jobs, "gitleaks")

    assert String.contains?(gitleaks, "gitleaks")
    assert Regex.match?(~r/^\s+- run: gitleaks detect --source \. --verbose\s*$/m, gitleaks)
    refute String.contains?(gitleaks, "needs: prep")
    refute String.contains?(gitleaks, "mix precommit")
    refute String.contains?(gitleaks, "mix gitleaks")
    refute String.contains?(gitleaks, "actions/download-artifact")
  end

  test "outdated precommit runs are cancelled" do
    workflow = File.read!(@workflow)
    assert workflow =~ ~r/^concurrency:\n  group: precommit-/m
    assert workflow =~ ~r/cancel-in-progress:\s*true/
  end

  defp precommit_alias_entries(mix) do
    assert [_, body] = Regex.run(~r/precommit:\s*\[(.*?)\]/s, mix)

    Regex.scan(~r/"([^"]+)"/, body)
    |> Enum.map(&List.last/1)
  end

  defp mix_check("cmd -- " <> rest), do: rest
  defp mix_check("cmd " <> rest), do: rest
  defp mix_check(entry), do: entry

  defp job_runs_check?(body, "compile --warnings-as-errors") do
    Regex.match?(~r/^\s+- run: mix compile --force --warnings-as-errors\s*$/m, body)
  end

  defp job_runs_check?(body, "gitleaks detect --source . --verbose") do
    Regex.match?(~r/^\s+- run: gitleaks detect --source \. --verbose\s*$/m, body)
  end

  defp job_runs_check?(body, mix_cmd) do
    Regex.match?(~r/^\s+- run: mix #{Regex.escape(mix_cmd)}\s*$/m, body)
  end

  defp workflow_jobs(yaml) do
    jobs_block =
      case String.split(yaml, ~r/^jobs:\s*$/m, parts: 2) do
        [_, rest] -> rest
        _ -> ""
      end

    Regex.scan(~r/^  ([A-Za-z0-9_-]+):\n([\s\S]*?)(?=^  [A-Za-z0-9_-]+:|\z)/m, jobs_block)
    |> Enum.map(fn [_, name, body] -> {name, body} end)
  end
end
