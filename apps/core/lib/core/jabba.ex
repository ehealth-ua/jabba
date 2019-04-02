defmodule Core.Jabba do
  @moduledoc false

  alias Core.Job
  alias Core.Jobs
  alias Kaffe.Producer

  require Logger

  @status_pending Job.status(:pending)
  @status_consumed Job.status(:consumed)
  @status_processed Job.status(:processed)
  @status_failed Job.status(:failed)

  @kafka_producer Application.get_env(:core, :kafka)[:producer]
  @rpc_worker Application.get_env(:core, :rpc_worker)

  def run(mfa, type, meta, opts \\ []) do
    with {:ok, job} <- create_job(mfa, type, meta) do
      @kafka_producer.publish_job(job.id)
    end
  end

  defp create_job(mfa, type, meta) do
    Jobs.create(%{
      mfa: mfa,
      meta: meta,
      type: type,
      status: @status_pending
    })
  end

  def consume(job_id) when is_binary(job_id) do
    with %Job{status: @status_pending} = job <- Jobs.get_by(job_id),
         %Job{} = job <- Jobs.update(job, status: @status_consumed) do
      case call_rpc(job) do
        {:ok, result} -> Jobs.processed(job, result)
        {:error, error} -> Jobs.failed(job, error)
      end
    else
      %Job{status: status} ->
        Logger.warn(fn -> "Job with id `#{job_id}` has invalid status `#{status}`" end)

      nil ->
        Logger.warn(fn -> "Job with id `#{job_id}` not found" end)
    end

    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "unknown kafka message: #{inspect(value)}" end)
    :ok
  end

  def handle_messages(messages) do
    for %{offset: offset, value: message} <- messages do
      value = :erlang.binary_to_term(message)
      Logger.debug(fn -> "message: " <> inspect(value) end)
      Logger.info(fn -> "offset: #{offset}" end)
      :ok = consume(value)
    end

    # Important!
    :ok
  end

  defp call_rpc(%Job{} = job) do
    try do
      apply(@rpc_worker, :run, Tuple.to_list(job.callback))
    rescue
      err -> Jobs.rescued(job, err)
    end
  end
end
