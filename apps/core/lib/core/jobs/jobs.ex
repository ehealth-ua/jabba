defmodule Core.Jobs do
  @moduledoc false

  alias Core.Job
  alias Core.Repo

  @status_consumed Job.status(:consumed)
  @status_processed Job.status(:processed)
  @status_failed Job.status(:failed)
  @status_rescued Job.status(:rescued)

  def get_by(params), do: Repo.get_by(Job, params)

  def create(data) do
    %Job{}
    |> Job.changeset(data)
    |> Repo.insert()
  end

  def update(job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  def consumed(job), do: update(job, %{status: @status_consumed})

  def processed(job, result) when is_map(result) do
    update(job, %{
      result: result,
      status: @status_processed
    })
  end

  def processed(job, result), do: processed(job, %{success: inspect(result)})

  def failed(job, result) when is_map(result) do
    update(job, %{
      result: result,
      status: @status_failed
    })
  end

  def failed(job, result), do: failed(job, %{error: inspect(result)})

  def rescued(job, result) do
    update(job, %{
      result: %{error: inspect(result)},
      status: @status_rescued
    })
  end
end
