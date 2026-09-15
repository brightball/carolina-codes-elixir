defmodule CarolinaCodesElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :carolina_codes_elixir,
      version: "0.2.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      releases: [
        carolina_codes_elixir: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {CarolinaCodesElixir.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.9"},
      {:bandit, "~> 1.7"},
      {:jason, "~> 1.4"},
      {:mint, "~> 1.10"},
      {:postgrex, "~> 0.20"},
      {:req, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --check-unused",
        "deps.audit",
        "format --check-formatted",
        "credo --strict",
        "sobelow --exit --threshold high --skip",
        "cmd -- gitleaks detect --source . --verbose",
        "test"
      ]
    ]
  end
end
