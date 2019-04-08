defmodule Jabba.RPC do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Core.Job
  alias Core.Jobs

  @type job() :: %{
          id: binary,
          type: binary,
          status: binary,
          callback: Jabba.callback(),
          meta: map,
          result: map,
          ended_at: DateTime,
          inserted_at: DateTime,
          updated_at: DateTime
        }

  @doc """
  Creates a new asynchronous job, which will be stored in PostgreSQL and processed through Kafka.

  Jabba just a job manager and stores result of callback with meta data.
  Jobs logic is on the side of the caller

  The first argument is the `callback` is being invoked. It is called when message consumed from Kafka.
  The result of the `callback` must return:
    * `{:ok, map}` or `:ok`  - in case of success
    * `{:error, map}` - in case of error

  The second argument defines a job `type` and could be used as a filter for jobs searching

  ## Options

  * `:strategy` - job processing strategy. Available: `:sequentially`. Read more in about strategy below

  * `:meta` - additional data for the job that stored in database
    and could be used as a filter for jobs searching

  * `:name` - job name that stored in database

  ## Strategies

  * `:sequentially` - Default strategy. Execute each job task step by step.
    In case of error task and job will be marked as failed.
    All tasks after failed task will be marked as `ABORTED`

  Returns `{:ok, %Job{}` tuple with job that was created
  or `{:error, term}` tuple with error reason

  ## Examples
    iex> Jabba.RPC.create_job(
    ...>   {"il", Core.RPC, :deactivate_legal_entity, ["2e7141ac-d021-448f-a71a-f6ea454a06b8"]},
    ...>   "deactivation_legal_entity",
    ...>   [
    ...>     meta: %{
    ...>       request_id: "197bed61-5e4b-49d1-b064-5830c8f18146",
    ...>       legal_entity_id: "2e7141ac-d021-448f-a71a-f6ea454a06b8"
    ...>     }
    ...>   ]
    ...> )
    {:ok, %Job{id: "227bed61-5e1b-36c1-a064-5830c8f18131", ...}}

  """
  @spec create_job(Jabba.callback() | list(Jabba.callback()), binary, list) :: {:ok, job()} | {:error, term}
  defdelegate create_job(callback, type, opts \\ []), to: Jabba, as: :run

  @doc """
  Get Job by id
  """
  @spec get_job(id :: binary) :: {:ok, job}
  def get_job(id) when is_binary(id) do
    with {:ok, job} <- Jobs.fetch_by(id: id) do
      {:ok, render(job)}
    end
  end

  @doc """
  Search for Jobs
  """
  @spec search_jobs(list | [], list | [], {offset :: integer, limit :: integer} | nil) :: {:ok, list(job)}
  def search_jobs(filter \\ [], order_by \\ [], cursor \\ nil) do
    with {:ok, jobs} <- Jobs.search_jobs(filter, order_by, cursor) do
      {:ok, Enum.map(jobs, &render/1)}
    end
  end

  defp render(job), do: Map.take(job, Job.__schema__(:fields))
end
