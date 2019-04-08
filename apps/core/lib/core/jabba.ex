defmodule Jabba do
  @moduledoc """
  Entry point for Jobs
  Module that creates and process jobs.
  """

  alias Core.Job
  alias Core.Jobs
  alias Core.Task

  require Logger

  @status_pending Job.status(:pending)
  @status_processed Job.status(:processed)
  @statuses_failed Task.statuses(:failed)

  @strategy_sequentially Job.strategy(:sequentially)

  @kafka_producer Application.get_env(:core, :kafka)[:producer]

  @defaults [
    strategy: @strategy_sequentially,
    meta: nil,
    name: nil
  ]

  @type callback() :: {binary, atom, atom, list}

  @spec run(callback, binary, list) :: {:ok, binary} | {:error, term}
  def run(callback, type, opts \\ []) when is_list(opts) do
    opts = options(opts)

    with {:ok, job} <- create_job(callback, type, opts),
         :ok <- publish_job_task(job) do
      {:ok, job}
    end
  end

  defp create_job(callback, type, opts) do
    Jobs.create_job(%{
      name: opts[:name],
      type: type,
      meta: opts[:meta],
      strategy: opts[:strategy],
      status: @status_pending,
      tasks: prepare_tasks(callback, opts[:strategy])
    })
  end

  defp prepare_tasks(callback, strategy) when is_tuple(callback), do: prepare_tasks([callback], strategy)

  defp prepare_tasks(callbacks, @strategy_sequentially) when is_list(callbacks) do
    callbacks
    |> Enum.map_reduce(1, fn callback, acc ->
      {%{callback: callback, priority: acc}, acc + 1}
    end)
    |> elem(0)
  end

  defp publish_job_task(%Job{strategy: @strategy_sequentially} = job) do
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

  defp prepare_error({:error, reason} = err) do
    Logger.error("Cannot publish task with: `#{inspect(reason)}`")
    err
  end

  defp prepare_error(err), do: prepare_error({:error, err})

  def proceed(%Task{status: @status_processed, job: %Job{strategy: @strategy_sequentially} = job} = task) do
    case Jobs.get_next_task(job.strategy, job.id, task.priority) do
      nil ->
        Jobs.processed(job)

      %Task{} = task ->
        @kafka_producer.publish_task(task.id)
        Jobs.pending(task)
    end
  end

  def proceed(%Task{status: status, job: %Job{strategy: @strategy_sequentially} = job} = task)
      when status in @statuses_failed do
  end

  defp options(overrides), do: Keyword.merge(@defaults, overrides)
end
