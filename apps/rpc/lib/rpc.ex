defmodule Jabba.RPC do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  import Jabba.RPC.View, only: [render: 1]

  alias Core.Ecto.RPCCallback
  alias Core.Job
  alias Core.Jobs

  @doc """
  Creates a new asynchronous job, which will be stored in PostgreSQL and processed through Kafka.

  Jabba just a job manager and stores result of callback with meta data.
  Jobs logic is on the side of the caller

  The first argument is list of `tasks` or one `task` map.
  Task is a map with two atom fields:
  * `:callback` - the callback is being invoked. It is called when message consumed from Kafka.
    The result of the `callback` must return:
    * `{:ok, map}` or `:ok`  - in case of success
    * `{:error, map}` - in case of error

  * `:name` (optional) - name of the task

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
        {"il", Core.RPC, :deactivate_legal_entity, ["2e7141ac-d021-448f-a71a-f6ea454a06b8"]},
        "deactivation_legal_entity",
        [
          meta: %{
            request_id: "197bed61-5e4b-49d1-b064-5830c8f18146",
            legal_entity_id: "2e7141ac-d021-448f-a71a-f6ea454a06b8"
          }
        ]
      )
      {:ok, %{
        id: "6868d53f-6e37-46bc-af34-29e650446310",
        type: "deactivate_legal_entity",
        status: "PENDING",
        meta: %{},
        result: %{},
        ended_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }}
  """
  @spec create_job(RPCCallback.t() | list(RPCCallback.t()), binary, list) :: {:ok, Job.t()} | {:error, term}
  defdelegate create_job(callback, type, opts \\ []), to: Jabba, as: :run

  @doc """
  Get Job by id

    ## Examples
      iex> Jabba.RPC.get_job()
      {:ok, %{
        id: "6868d53f-6e37-46bc-af34-29e650446310",
        type: "deactivate_legal_entity",
        status: "PROCESSED",
        meta: %{},
        result: %{},
        ended_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }}
  """
  @spec get_job(id :: binary) :: {:ok, Job.t()}
  def get_job(id) when is_binary(id) do
    with {:ok, job} <- Jobs.fetch_job_by(id: id) do
      {:ok, render(job)}
    end
  end

  @doc """
  Search for Jobs
  Check available formats for filter here https://github.com/edenlabllc/ecto_filter

  Available parameters:

  | Parameter           | Type                          | Example                                   |
  | :-----------------: | :---------------------------: | :---------------------------------------: |
  | filter              | `list`                        | `[{:status, :equal, "NEW"}]`              |
  | order_by            | `list`                        | `[asc: :inserted_at]` or `[desc: :status]`|
  | cursor              | `{integer, integer}` or `nil` | `{0, 10}`                                 |

  ## Examples
      iex> Jabba.RPC.search_jobs([{:status, :equal, "PROCESSED"}], [desc: :status], {0, 10})
      {:ok, [%{
        id: "6868d53f-6e37-46bc-af34-29e650446310",
        type: "deactivate_legal_entity",
        status: "PROCESSED",
        meta: %{},
        result: %{},
        ended_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }]}
  """
  @spec search_jobs(list | [], list | [], {offset :: integer, limit :: integer} | nil) :: {:ok, list(Job.t())}
  def search_jobs(filter \\ [], order_by \\ [], cursor \\ nil) do
    with {:ok, jobs} <- Jobs.search_jobs(filter, order_by, cursor) do
      {:ok, Enum.map(jobs, &render/1)}
    end
  end
end
