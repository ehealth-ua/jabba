defmodule Jabba do
  @moduledoc """
  Entry point for Jobs
  Module that creates and process jobs.
  """

  import Core.Ecto.RPCCallback, only: [is_callback: 1]

  alias Core.Ecto.RPCCallback
  alias Core.Job
  alias Core.Jobs
  alias Core.RPC.Client, as: RPC
  alias Core.Task

  require Logger

  @status_pending Job.status(:pending)
  @status_processed Job.status(:processed)
  @statuses_failed Task.statuses(:failed)

  @strategy_sequentially Job.strategy(:sequentially)
  @strategy_concurrent Job.strategy(:concurrent)

  @kafka_producer Application.get_env(:core, :kafka)[:producer]

  @defaults [
    strategy: @strategy_sequentially,
    meta: nil,
    name: nil
  ]

  def run(tasks, type, opts \\ [])

  @spec run(list(RPCCallback.t()), binary, list) :: {:ok, binary} | {:error, term}
  def run(tasks, type, opts) when is_list(tasks) and is_list(opts) do
    opts = options(opts)

    with {:ok, job} <- create_job(tasks, type, opts),
         :ok <- publish_job_tasks(job) do
      {:ok, job}
    end
  end

  @spec run(RPCCallback.t(), binary, list) :: {:ok, binary} | {:error, term}
  def run(task, type, opts) when is_map(task), do: run([task], type, opts)

  defp create_job(tasks, type, opts) do
    Jobs.create_job(%{
      name: opts[:name],
      type: type,
      meta: opts[:meta],
      callback: opts[:callback],
      strategy: opts[:strategy],
      status: @status_pending,
      tasks: prepare_tasks(tasks, opts[:strategy])
    })
  end

  defp prepare_tasks(tasks, @strategy_sequentially) when is_list(tasks) do
    tasks
    |> Enum.map_reduce(1, fn task, acc ->
      {task |> Map.take(~w(callback name)a) |> Map.put(:priority, acc), acc + 1}
    end)
    |> elem(0)
  end

  defp prepare_tasks(tasks, @strategy_concurrent), do: tasks

  defp publish_job_tasks(%Job{strategy: @strategy_sequentially} = job) do
    with %{id: id} = task <- Enum.find(job.tasks, fn task -> task.priority == 1 end),
         {:ok, _} <- Jobs.pending(task),
         :ok <- @kafka_producer.publish_task(id) do
      :ok
    else
      nil ->
        Logger.error("Cannot publish task: no tasks with priority 1")
        :ok

      err ->
        prepare_error(err)
    end
  end

  defp publish_job_tasks(%Job{strategy: @strategy_concurrent} = job) do
    ids = Enum.map(job.tasks, &Map.get(&1, :id))

    with :ok <- Jobs.pending_tasks(ids),
         :ok <- @kafka_producer.publish_tasks(ids) do
      :ok
    else
      err -> prepare_error(err)
    end
  end

  defp prepare_error({:error, reason} = err) do
    Logger.error("Cannot publish task with: `#{inspect(reason)}`")
    err
  end

  defp prepare_error(err), do: prepare_error({:error, err})

  def proceed(%Task{status: @status_processed, job: %Job{strategy: @strategy_sequentially} = job} = task) do
    case Jobs.get_next_task(job.strategy, job.id, task.priority) do
      nil ->
        job |> Jobs.processed() |> call_job_rpc()

      %Task{} = task ->
        with {:ok, _} <- Jobs.pending(task),
             :ok <- @kafka_producer.publish_task(task.id) do
          :ok
        end
    end
  end

  def proceed(%Task{status: status, job: %Job{strategy: @strategy_sequentially} = job})
      when status in @statuses_failed do
    Jobs.abort_new_tasks(job.id)
    job |> Jobs.failed() |> call_job_rpc()
  end

  def proceed(%Task{status: @status_processed, job: %Job{strategy: @strategy_concurrent} = job}) do
    case Jobs.has_tasks_in_process?(job.strategy, job.id) do
      false -> job |> Jobs.processed() |> call_job_rpc()
      true -> :ok
    end
  end

  def proceed(%Task{status: status, job: %Job{strategy: @strategy_concurrent} = job})
      when status in @statuses_failed do
    job |> Jobs.failed() |> call_job_rpc()
  end

  defp call_job_rpc(%Job{callback: callback} = job) when is_callback(callback) do
    {basename, module, function, arguments} = callback
    arguments = List.insert_at(arguments, -1, %{job_id: job.id, status: job.status})

    RPC.safe_callback({basename, module, function, arguments})
  end

  defp call_job_rpc(_), do: :ok

  defp options(overrides), do: Keyword.merge(@defaults, overrides)
end
