defmodule Core.Kafka.TaskProcessor do
  @moduledoc """
  Consume message from Kafka and call RPC for Task
  """

  alias Core.Jobs
  alias Core.RPC.Client, as: RPC
  alias Core.Task

  require Logger

  @status_pending Task.status(:pending)

  def consume(task_id) when is_binary(task_id) do
    with %Task{status: @status_pending} = task <- Jobs.get_task_by([id: task_id], :preload),
         {:ok, _} <- Jobs.consumed(task),
         result <- call_rpc(task),
         {_, {:ok, updated_task}} <- {:process_rpc, process_rpc_result(task, result)} do
      Jabba.proceed(updated_task)
    else
      %Task{status: status} ->
        Logger.warn(fn -> "Task with id `#{task_id}` has invalid status `#{status}`" end)

      nil ->
        Logger.warn(fn -> "Task with id `#{task_id}` not found" end)

      {:process_rpc, {:error, error}} ->
        Logger.warn(fn -> "Task with id `#{task_id}` cannot be processed because of #{inspect(error)}" end)
    end

    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "Unknown kafka message: `#{inspect(value)}`" end)
    :ok
  end

  def handle_messages(messages) do
    for %{offset: offset, value: task_id} <- messages do
      Logger.debug(fn -> "Task id: " <> inspect(task_id) end)
      Logger.debug(fn -> "Offset: #{offset}" end)
      :ok = consume(task_id)
    end

    # Important!
    :ok
  end

  defp call_rpc(%Task{callback: callback}), do: RPC.safe_callback(callback)

  defp process_rpc_result(task, {:ok, result}), do: Jobs.processed(task, result)
  defp process_rpc_result(task, {:error, error}), do: Jobs.failed(task, error)
  defp process_rpc_result(task, {:rescued, error}), do: Jobs.rescued(task, error)
  defp process_rpc_result(task, result), do: Jobs.processed(task, result)
end
