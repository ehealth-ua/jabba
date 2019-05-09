defmodule Jabba.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.1.0"

  def project do
    [
      version: @version,
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test],
      deps: deps()
    ]
  end

  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:excoveralls, "~> 0.10", only: [:dev, :test]},
      {:git_ops, "~> 0.6.0", only: [:dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test]}
    ]
  end
end
