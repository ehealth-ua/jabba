defmodule Core.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Core.Repo

  alias Core.Job
  alias Core.Task

  def job_factory do
    %Job{
      name: sequence(:name, &"job-#{&1}"),
      type: "test",
      strategy: Job.strategy(:sequentially),
      status: Job.status(:pending),
      meta: %{},
      ended_at: nil
    }
  end

  def task_factory do
    %Task{
      callback: {"test", TestRPC, :run, []},
      status: Job.status(:pending),
      result: %{},
      ended_at: nil
    }
  end
end
