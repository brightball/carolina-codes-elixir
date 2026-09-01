defmodule CarolinaCodesElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :carolina_codes_elixir,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        carolina_codes_elixir: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CarolinaCodesElixir.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.7"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"},
      {:postgrex, "~> 0.20"},
      {:req, "~> 0.5"}
    ]
  end
end
