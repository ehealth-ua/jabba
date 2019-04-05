defmodule RPC.ReleaseTasks do
  @moduledoc """
  Nice way to apply migrations inside a released application.

  Example:

      rpc/bin/rpc command rpc_tasks migrate!
  """

  alias Core.Repo

  def migrate do
    migrations_dir = Application.app_dir(:core, "priv/repo/migrations")

    load_app()
    run_migration(Repo, migrations_dir)

    System.halt(0)
    :init.stop()
  end

  defp load_app do
    start_applications([:logger, :postgrex, :ecto, :ecto_sql])
    Application.load(:mpi)
  end

  defp start_applications(apps) do
    Enum.each(apps, fn app ->
      {_, _message} = Application.ensure_all_started(app)
    end)
  end

  def run_migration(repo, migrations_dir) do
    repo.start_link()
    Ecto.Migrator.run(repo, migrations_dir, :up, all: true)
  end
end
