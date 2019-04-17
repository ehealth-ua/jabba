defmodule Core.Jobs do
  @moduledoc false

  import Core.Ecto.Query, only: [apply_cursor: 2]
  import Ecto.Query

  alias Core.Filters.Base, as: BaseFilter
  alias Core.Job
  alias Core.Repo
  alias Core.Task

  @status_pending Job.status(:pending)
  @status_processed Job.status(:processed)
  @status_failed Job.status(:failed)
  @status_new Task.status(:new)
  @status_consumed Task.status(:consumed)
  @status_aborted Task.status(:aborted)
  @status_rescued Task.status(:rescued)

  @strategy_sequentially Job.strategy(:sequentially)

  def get_job_by(params), do: Repo.get_by(Job, params)

  def get_job_by(params, :preload) do
    Job
    |> where(^params)
    |> preload(:tasks)
    |> Repo.one()
  end

  def get_task_by(params), do: Repo.get_by(Task, params)

  def get_task_by(params, :preload) do
    Task
    |> where(^params)
    |> preload(:job)
    |> Repo.one()
  end

  def fetch_job_by(params) do
    case get_job_by(params) do
      %Job{} = job -> {:ok, job}
      err -> err
    end
  end

  def fetch_task_by(params) do
    case get_task_by(params) do
      %Task{} = job -> {:ok, job}
      err -> err
    end
  end

  @spec search_jobs(list | [], list | [], {offset :: integer, limit :: integer} | nil) :: {:ok, Job.t() | nil}
  def search_jobs(filter \\ [], order_by \\ [], cursor \\ nil) do
    jobs =
      Job
      |> BaseFilter.filter(filter)
      |> apply_cursor(cursor)
      |> order_by(^order_by)
      |> Repo.all()

    {:ok, jobs}
  end

  def create_job(data) do
    %Job{}
    |> Job.changeset(data)
    |> Repo.insert()
  end

  def update_job(job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  def update_task(task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def get_next_task(@strategy_sequentially, job_id, current_priority) do
    Task
    |> where(job_id: ^job_id, status: @status_new)
    |> where([t], t.priority > ^current_priority)
    |> limit(1)
    |> order_by(asc: :priority)
    |> Repo.one()
  end

  def abort_new_tasks(job_id) do
    Task
    |> where(job_id: ^job_id, status: @status_new)
    |> Repo.update_all(set: [status: @status_aborted])
  end

  # task statuses

  def consumed(%Task{} = entity), do: update_task(entity, %{status: @status_consumed})
  def pending(%Task{} = entity), do: update_task(entity, %{status: @status_pending})
  def aborted(%Task{} = entity), do: update_task(entity, %{status: @status_aborted})

  def rescued(%Task{} = entity, result) do
    update_task(entity, %{
      result: %{error: inspect(result)},
      status: @status_rescued
    })
  end

  # processed

  def processed(%Job{} = entity), do: update_job(entity, %{status: @status_processed})

  def processed(%Task{} = entity, result) when is_map(result) do
    update_task(entity, %{
      result: result,
      status: @status_processed
    })
  end

  def processed(entity, result), do: processed(entity, %{success: inspect(result)})

  # failed

  def failed(%Job{} = entity), do: update_job(entity, %{status: @status_failed})

  def failed(%Task{} = entity, result) when is_map(result) do
    update_task(entity, %{
      result: result,
      status: @status_failed
    })
  end

  def failed(entity, result), do: failed(entity, %{error: inspect(result)})
end
