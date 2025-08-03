defmodule AshCircuitBreaker.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description """
  An extension for Ash.Resource which adds the ability to wrap actions in circuit breakers to allow for graceful handling of and recovery from failures.
  """

  def project do
    [
      app: :ash_circuit_breaker,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      dialyzer: [plt_add_apps: [:mix]],
      docs: docs(),
      aliases: aliases(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp package do
    [
      maintainers: [
        "Christian Alexander <christian@linux.com>"
      ],
      licenses: ["MIT"],
      links: %{
        "Source" => "https://github.com/christianalexander/ash_circuit_breaker",
        "Ash" => "https://www.ash-hq.org/"
      },
      source_url: "https://github.com/christianalexander/ash_circuit_breaker",
      files: ~w[lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "documentation/dsls/DSL-AshCircuitBreaker.md"
      ],
      filter_modules: ~r/^Elixir\.AshCircuitBreaker/
    ]
  end

  defp aliases do
    [
      "spark.formatter": "spark.formatter --extensions AshCircuitBreaker",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshCircuitBreaker",
      docs: ["spark.cheat_sheets", "docs"],
      credo: "credo --strict"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.5.33"},
      {:spark, "~> 2.0"},
      {:fuse, "~> 2.4"},
      {:plug, "~> 1.17", optional: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test], optional: true},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.7", only: [:dev, :test], optional: true}
    ]
  end
end
