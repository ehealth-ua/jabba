defmodule Core.JabbaTest do
  @moduledoc false

  use Core.ModelCase
  import ExUnit.CaptureLog
  alias Core.Job
  alias Core.Jobs
  alias Ecto.UUID

  @test_callback {"test", Test, :run, [:some, %{arguments: "for"}, [:callback]]}

  describe "create job" do
    test "successfully with empty meta" do
      expect(KafkaMock, :publish_job, fn _ -> :ok end)

      assert {:ok, %Job{id: id}} = Jabba.run(@test_callback, "test")

      assert %Job{} = job = Jobs.get_by(id: id)
      assert "test" == job.type
      assert Job.status(:pending) == job.status
    end

    test "successfully when meta is map" do
      expect(KafkaMock, :publish_job, fn _ -> :ok end)
      request_id = UUID.generate()

      assert {:ok, %Job{id: id}} = Jabba.run(@test_callback, "test", meta: %{request_id: request_id})

      assert %Job{} = job = Jobs.get_by(id: id)
      assert "test" == job.type
      assert Job.status(:pending) == job.status
      assert %{"request_id" => request_id} == job.meta
    end

    test "with invalid meta type" do
      Jabba.run(@test_callback, "test", meta: "invalid type")
    end
  end

  describe "consume" do
    test "successfully processed" do
      expect(RPCWorkerMock, :run, fn basename, module, function, arguments ->
        assert "test" == basename
        assert Test == module
        assert :run == function
        assert [:some, %{arguments: "for"}, [:callback]] == arguments

        {:ok, {:ok, %{job: :done}}}
      end)

      job = insert(:job, callback: @test_callback)
      assert :ok = Jabba.consume(job.id)

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:processed) == db_job.status
      assert %{"job" => "done"} == db_job.result
    end

    test "successfully processed with invalid return format" do
      expect(RPCWorkerMock, :run, fn _, _, _, _ ->
        {:ok, "not a tuple"}
      end)

      job = insert(:job)
      assert :ok = Jabba.consume(job.id)

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:processed) == db_job.status
      assert %{"success" => ~s("not a tuple")} = db_job.result
    end

    test "invalid id" do
      assert capture_log(fn ->
               :ok = Jabba.consume(:not_a_string)
             end) =~ "unknown kafka message: `:not_a_string`"
    end

    test "failed because of invalid RPC call" do
      expect(RPCWorkerMock, :run, fn _, _, _, _ ->
        {:error, {:bad_rpc, [:pod_not_connected]}}
      end)

      job = insert(:job)
      assert :ok = Jabba.consume(job.id)

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:failed) == db_job.status
      assert %{"error" => _} = db_job.result
    end

    test "failed because of result of RPC call" do
      expect(RPCWorkerMock, :run, fn _, _, _, _ ->
        {:ok, {:error, %{reason: :not_found}}}
      end)

      job = insert(:job)
      assert :ok = Jabba.consume(job.id)

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:failed) == db_job.status
      assert %{"reason" => "not_found"} = db_job.result
    end

    test "do not process Job that was already processed" do
      job = insert(:job, status: Job.status(:processed))

      assert capture_log(fn ->
               :ok = Jabba.consume(job.id)
             end) =~ "Job with id `#{job.id}` has invalid status `#{Job.status(:processed)}`"
    end

    test "rescued because of RPC error" do
      expect(RPCWorkerMock, :run, fn _, _, _, _ ->
        raise "Some error"
      end)

      job = insert(:job)
      assert :ok = Jabba.consume(job.id)

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:rescued) == db_job.status
      assert %{"error" => ~s(%RuntimeError{message: "Some error"})} = db_job.result
    end
  end

  describe "handle_messages" do
    test "successfully processed" do
      expect(RPCWorkerMock, :run, fn _, _, _, _ -> {:ok, {:ok, %{job: :done}}} end)

      job = insert(:job)
      assert :ok = Jabba.handle_messages([%{offset: 0, value: job.id}])

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:processed) == db_job.status
      assert %{"job" => "done"} == db_job.result
    end
  end
end
