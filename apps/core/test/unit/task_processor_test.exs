defmodule Core.TaskProcessorTest do
  @moduledoc false

  @test_callback {"test", Test, :run, [:some, %{arguments: "for"}, [:callback]]}

  use Core.ModelCase
  import ExUnit.CaptureLog
  alias Core.Kafka.TaskProcessor
  alias Core.Job
  alias Core.Jobs
  alias Core.Task

  describe "consume" do
    test "successfully processed" do
      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "test" == basename
        assert Test == module
        assert :run == function
        assert [:some, %{arguments: "for"}, [:callback]] == arguments

        {:ok, {:ok, %{job: :done}}}
      end)

      job =
        :job
        |> insert()
        |> with_tasks(callback: @test_callback, status: Task.status(:pending))
        |> assert_consume()

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Job.status(:processed) == db_job.status

      task = hd(db_job.tasks)

      assert Job.status(:processed) == task.status
      assert %{"job" => "done"} == task.result
    end

    test "successfully processed with invalid return format" do
      expect(RPCClientMock, :run, fn _, _, _, _ ->
        {:ok, "not a tuple"}
      end)

      job = consume_task()

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Job.status(:processed) == db_job.status

      task = hd(db_job.tasks)

      assert Job.status(:processed) == task.status
      assert %{"success" => ~s("not a tuple")} = task.result
    end

    test "invalid id" do
      assert capture_log(fn ->
               :ok = TaskProcessor.consume(:not_a_string)
             end) =~ "Unknown kafka message: `:not_a_string`"
    end

    test "failed because of invalid RPC call" do
      expect(RPCClientMock, :run, fn _, _, _, _ ->
        {:error, {:bad_rpc, [:pod_not_connected]}}
      end)

      job = consume_task()

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Task.status(:failed) == db_job.status

      task = hd(db_job.tasks)
      assert Task.status(:failed) == task.status
      assert %{"error" => _} = task.result
    end

    test "failed because of result of RPC call" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)

      expect(RPCClientMock, :run, fn _, _, _, _ -> {:ok, :ok} end)

      expect(RPCClientMock, :run, fn _, _, _, _ ->
        {:ok, {:error, %{reason: :not_found}}}
      end)

      job = insert(:job)
      %{id: task1_id} = insert(:task, job: job, priority: 1, status: Task.status(:pending))
      %{id: task2_id} = insert(:task, job: job, priority: 2)
      %{id: task3_id} = insert(:task, job: job, priority: 3)

      assert :ok = TaskProcessor.consume(task1_id)
      assert :ok = TaskProcessor.consume(task2_id)

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Job.status(:failed) == db_job.status

      Enum.each(db_job.tasks, fn task ->
        case task.id do
          ^task1_id ->
            assert Task.status(:processed) == task.status
            assert %{"success" => ":ok"} = task.result

          ^task2_id ->
            assert Task.status(:failed) == task.status
            assert %{"reason" => "not_found"} = task.result

          ^task3_id ->
            assert Task.status(:aborted) == task.status
            assert %{} = task.result
        end
      end)
    end

    test "do not process Job that was already processed" do
      job = insert(:job)
      task = insert(:task, job: job, status: Task.status(:processed))

      assert capture_log(fn ->
               :ok = TaskProcessor.consume(task.id)
             end) =~ "Task with id `#{task.id}` has invalid status `#{Task.status(:processed)}`"
    end

    test "rescued because of RPC error" do
      expect(RPCClientMock, :run, fn _, _, _, _ ->
        raise "Some error"
      end)

      job = consume_task()

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Task.status(:failed) == db_job.status

      task = hd(db_job.tasks)
      assert Task.status(:rescued) == task.status
      assert %{"error" => ~s(%RuntimeError{message: "Some error"})} = task.result
    end
  end

  describe "handle_messages" do
    test "successfully processed" do
      expect(RPCClientMock, :run, fn _, _, _, _ -> {:ok, {:ok, %{job: :done}}} end)

      job = insert(:job)
      task = insert(:task, job: job, status: Task.status(:pending))
      assert :ok = TaskProcessor.handle_messages([%{offset: 0, value: task.id}])

      db_job = Jobs.get_job_by([id: job.id], :preload)
      assert Job.status(:processed) == db_job.status

      task = hd(db_job.tasks)
      assert Task.status(:processed) == task.status
      assert %{"job" => "done"} == task.result
    end
  end

  defp consume_task do
    :job
    |> insert()
    |> with_tasks(status: Task.status(:pending))
    |> assert_consume()
  end

  defp assert_consume(%Job{tasks: [task | _]} = job) do
    assert :ok = TaskProcessor.consume(task.id)
    job
  end
end
