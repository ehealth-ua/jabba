defmodule RPC.ReleaseTasks do
  @moduledoc """
  Nice way to apply migrations inside a released application.

  Example:
    iex> rpc/bin/rpc command rpc_tasks migrate
    iex> rpc/bin/rpc command rpc_tasks seed
  """

  @start_apps ~w(
    core
    logger
    logger_json
    postgrex
    ecto
    ecto_sql
  )a

  @repos [
    Core.Repo
  ]

  def migrate do
    start_applications()
    run_migrations()
    shutdown()
  end

  defp run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    Ecto.Migrator.run(repo, migrations_path(), :up, all: true)
  end

  def seed do
    start_applications()

    seed_script = seed_path()
    IO.puts("Looking for seed script..")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end

    shutdown()
  end

  defp start_applications do
    IO.puts("Starting applications..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    IO.puts("Starting repos..")
    Enum.each(@repos, & &1.start_link())
  end

  defp shutdown do
    IO.puts("Success!")
    System.halt(0)
    :init.stop()
  end

  defp migrations_path, do: Application.app_dir(:core, "priv/repo/migrations")
  defp seed_path, do: Application.app_dir(:core, "priv/repo/seeder.exs")
end
