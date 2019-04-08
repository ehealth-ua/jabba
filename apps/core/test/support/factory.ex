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

  def with_tasks(job), do: with_tasks(job, 1)

  def with_tasks(job, args) when is_list(args), do: with_tasks(job, 1, args)

  def with_tasks(job, n, args \\ []) do
    tasks = insert_list(n, :task, [job: job] ++ args)
    %{job | tasks: tasks}
  end

  def task_factory do
    %Task{
      callback: {"test", TestRPC, :run, []},
      job: build(:job),
      priority: String.to_integer(sequence(:priority, &"#{&1}")),
      result: %{},
      status: Task.status(:new),
      ended_at: nil
    }
  end
end
