defmodule Core.Application do
  @moduledoc false

  use Application

  alias Kaffe.GroupMemberSupervisor

  def start(_type, _args) do
    env = Application.get_env(:core, :env)

    children =
      [{Core.Repo, []}]
      |> start_kafka(env)
      |> start_cluster(env)

    Application.put_env(:kaffe, :consumer, Application.get_env(:core, :kaffe_consumer))

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_kafka(children, env) when env != :test do
    children ++
      [
        %{
          id: GroupMemberSupervisor,
          start: {GroupMemberSupervisor, :start_link, []},
          type: :supervisor
        }
      ]
  end

  defp start_kafka(children, _env), do: children

  defp start_cluster(children, :prod) do
    topologies = Application.get_env(:core, :topologies)
    children ++ [{Cluster.Supervisor, [topologies, [name: Jabba.ClusterSupervisor]]}]
  end

  defp start_cluster(children, _env), do: children
end
