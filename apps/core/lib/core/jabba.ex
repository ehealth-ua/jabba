defmodule Jabba do
  @moduledoc false

  alias Core.Job
  alias Core.Jobs

  require Logger

  @status_pending Job.status(:pending)

  @kafka_producer Application.get_env(:core, :kafka)[:producer]
  @rpc_worker Application.get_env(:core, :rpc_worker)

  @defaults [
    meta: nil
  ]

  @type callback() :: {binary, atom, atom, list}

  @spec run(callback, binary, list) :: {:ok, binary} | {:error, term}
  def run(callback, type, opts \\ []) when is_list(opts) do
    opts = options(opts)

    with {:ok, job} <- create_job(callback, type, opts[:meta]),
         :ok <- @kafka_producer.publish_job(job.id) do
      {:ok, job.id}
    end
  end

  defp create_job(callback, type, meta) do
    Jobs.create(%{
      callback: callback,
      meta: meta,
      type: type,
      status: @status_pending
    })
  end

  def consume(job_id) when is_binary(job_id) do
    with %Job{status: @status_pending} = job <- Jobs.get_by(id: job_id),
         {:ok, %Job{} = job} <- Jobs.consumed(job),
         result <- call_rpc(job),
         {_, {:ok, _}} <- {:process_rpc, process_rpc_result(job, result)} do
      :ok
    else
      %Job{status: status} ->
        Logger.warn(fn -> "Job with id `#{job_id}` has invalid status `#{status}`" end)

      nil ->
        Logger.warn(fn -> "Job with id `#{job_id}` not found" end)

      {:process_rpc, {:error, error}} ->
        Logger.warn(fn -> "Job with id `#{job_id}` cannot be processed because of #{error}" end)
    end

    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "unknown kafka message: #{inspect(value)}" end)
    :ok
  end

  def handle_messages(messages) do
    for %{offset: offset, value: job_id} <- messages do
      Logger.debug(fn -> "job id: " <> inspect(job_id) end)
      Logger.debug(fn -> "offset: #{offset}" end)
      :ok = consume(job_id)
    end

    # Important!
    :ok
  end

  defp call_rpc(%Job{} = job) do
    case apply(@rpc_worker, :run, Tuple.to_list(job.callback)) do
      {:ok, result} ->
        result

      err ->
        Logger.warn(fn -> "Invalid RPC call with: `#{inspect(err)}`" end)
        err
    end
  rescue
    err -> {:rescued, err}
  end

  defp process_rpc_result(job, {:ok, result}), do: Jobs.processed(job, result)
  defp process_rpc_result(job, {:error, error}), do: Jobs.failed(job, error)
  defp process_rpc_result(job, {:rescued, error}), do: Jobs.rescued(job, error)
  defp process_rpc_result(job, result), do: Jobs.processed(job, result)

  defp options(overrides) do
    Keyword.merge(@defaults, overrides)
  end
end
