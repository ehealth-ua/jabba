defmodule Core.Jobs do
  @moduledoc false

  import Core.Ecto.Query, only: [apply_cursor: 2]
  import Ecto.Query

  alias Core.Filters.Base, as: BaseFilter
  alias Core.Job
  alias Core.Repo

  @status_consumed Job.status(:consumed)
  @status_processed Job.status(:processed)
  @status_failed Job.status(:failed)
  @status_rescued Job.status(:rescued)

  def get_by(params), do: Repo.get_by(Job, params)

  def fetch_by(params) do
    case get_by(params) do
      %Job{} = job -> {:ok, job}
      nil -> {:error, {:not_found, "Job not found"}}
    end
  end

  @spec search_jobs(list | [], list | [], {offset :: integer, limit :: integer} | nil) :: {:ok, term}
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

  def consumed(job), do: update_job(job, %{status: @status_consumed})

  def processed(job, result) when is_map(result) do
    update_job(job, %{
      result: result,
      status: @status_processed
    })
  end

  def processed(job, result), do: processed(job, %{success: inspect(result)})

  def failed(job, result) when is_map(result) do
    update_job(job, %{
      result: result,
      status: @status_failed
    })
  end

  def failed(job, result), do: failed(job, %{error: inspect(result)})

  def rescued(job, result) do
    update_job(job, %{
      result: %{error: inspect(result)},
      status: @status_rescued
    })
  end
end
