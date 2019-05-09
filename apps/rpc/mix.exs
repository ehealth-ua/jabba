defmodule RPC.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :rpc,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      compilers: Mix.compilers(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RPC.Application, []}
    ]
  end

  defp deps do
    [
      {:core, in_umbrella: true}
    ]
  end
end
