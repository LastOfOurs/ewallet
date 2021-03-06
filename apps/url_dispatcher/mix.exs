defmodule UrlDispatcher.Mixfile do
  use Mix.Project

  def project do
    [
      app: :url_dispatcher,
      version: "1.1.0-pre.2",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :cowboy, :plug, :admin_api, :admin_panel, :ewallet_api],
      mod: {UrlDispatcher.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:admin_api, in_umbrella: true},
      {:admin_panel, in_umbrella: true},
      {:deferred_config, "~> 0.1.0"},
      {:ewallet, in_umbrella: true},
      {:ewallet_api, in_umbrella: true},
      {:ewallet_config, in_umbrella: true},
      {:plug, "~> 1.2"},
      {:plug_cowboy, "~> 1.0"},
      {:quantum, "~> 2.2.6"},
      {:timex, "~> 3.0"}
    ]
  end
end
