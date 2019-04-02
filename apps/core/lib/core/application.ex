defmodule Core.Application do
  @moduledoc false

  use Application

  alias Kaffe.GroupMemberSupervisor

  def start(_type, _args) do
    children = [
      {Core.Repo, []},
      {GroupMemberSupervisor, type: :supervisor}
    ]

    children =
      if Application.get_env(:core, :env) == :prod do
        topologies = Application.get_env(:core, :topologies)
        children ++ [{Cluster.Supervisor, [topologies, [name: GraphQL.ClusterSupervisor]]}]
      else
        children
      end

    Application.put_env(:kaffe, :consumer, Application.get_env(:core, :kaffe_consumer))

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
