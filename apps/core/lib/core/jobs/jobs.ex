defmodule Core.Jobs do
  @moduledoc false

  alias Core.Job
  alias Core.Repo

  @status_pending Job.status(:pending)
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

  def processed(job, result) do
    update(job, result: result, status: @status_processed)
  end

  def failed(job, result) do
    update(job, result: result, status: @status_failed)
  end

  def rescued(job, result) do
    update(job, result: Jason.encode(inspect(result)), status: @status_rescued)
  end
end
