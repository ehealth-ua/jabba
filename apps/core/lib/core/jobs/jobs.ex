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
  @strategy_concurrent Job.strategy(:concurrent)

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
  def search_jobs(filter \\ [], order_by \\ [], cursor \\ nil), do: search(Job, filter, order_by, cursor)

  @spec search_tasks(list | [], list | [], {offset :: integer, limit :: integer} | nil) :: {:ok, Task.t() | nil}
  def search_tasks(filter \\ [], order_by \\ [], cursor \\ nil), do: search(Task, filter, order_by, cursor)

  defp search(entity, filter, order_by, cursor) do
    order_by = prepare_order_by(order_by)

    entities =
      entity
      |> BaseFilter.filter(filter)
      |> apply_cursor(cursor)
      |> order_by(^order_by)
      |> Repo.all()

    {:ok, entities}
  end

  # crooked nail. Should be removed
  # ToDo: use inserted_at instead of started_at
  defp prepare_order_by([]), do: []
  defp prepare_order_by(asc: :started_at), do: [asc: :inserted_at]
  defp prepare_order_by(desc: :started_at), do: [desc: :inserted_at]
  defp prepare_order_by(order_by), do: order_by

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

  def has_tasks_in_process?(@strategy_concurrent, job_id) do
    statuses = [@status_new, @status_pending, @status_consumed]

    pending_tasks =
      Task
      |> where(job_id: ^job_id)
      |> where([t], t.status in ^statuses)
      |> select([t], count(t.id))
      |> Repo.one()

    0 < pending_tasks
  end

  def abort_new_tasks(job_id) do
    Task
    |> where(job_id: ^job_id, status: @status_new)
    |> Repo.update_all(set: [status: @status_aborted])
  end

  # task statuses

  def aborted(%Task{} = entity), do: update_task(entity, %{status: @status_aborted})
  def consumed(%Task{} = entity), do: update_task(entity, %{status: @status_consumed})
  def pending(%Task{} = entity), do: update_task(entity, %{status: @status_pending})

  def pending_tasks(ids) when is_list(ids) do
    tasks_amount = length(ids)

    Task
    |> where([t], t.id in ^ids)
    |> Repo.update_all(set: [status: @status_pending])
    |> case do
      {^tasks_amount, nil} -> :ok
      _ -> {:error, "Tasks status was not updated to `#{@status_pending}`"}
    end
  end

  def rescued(%Task{} = entity, result) do
    update_task(entity, %{
      result: %{error: inspect(result)},
      status: @status_rescued
    })
  end

  # processed

  def processed(%Job{} = entity) do
    update_job(
      entity,
      %{
        status: @status_processed,
        ended_at: DateTime.utc_now()
      }
    )
  end

  def processed(%Task{} = entity, result) when is_map(result) do
    update_task(entity, %{
      result: result,
      status: @status_processed,
      ended_at: DateTime.utc_now()
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
