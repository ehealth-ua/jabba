defmodule Rpc.MixProject do
  use Mix.Project

  def project do
    [
      app: :rpc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rpc.Application, []}
    ]
  end

  defp deps do
    [
      {:core, in_umbrella: true},
      {:kube_rpc, "~> 0.1.0"}
    ]
  end
end
