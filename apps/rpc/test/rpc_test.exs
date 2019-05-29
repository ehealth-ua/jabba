defmodule RPCTest do
  use Core.ModelCase
  alias Core.Job
  alias Ecto.UUID
  alias Jabba.RPC

  @test_callback {"test", Test, :run, [:some, %{arguments: "for"}, [:callback]]}

  describe "create job with sequentially process strategy" do
    test "successfully with empty meta" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)

      {:ok, %Job{}} = RPC.create_job(%{callback: @test_callback, name: "name"}, "test")
    end
  end

  describe "search jobs" do
    test "success with filter params" do
      insert_list(4, :job, type: "terminate")
      insert_list(2, :job, type: "deactivate")
      job = insert(:job, type: "terminate")
      insert(:task, job: job)

      assert {:ok, jobs} = RPC.search_jobs([{:type, :equal, "terminate"}], [desc: :inserted_at], {0, 10})
      assert is_list(jobs)
      assert 5 == length(jobs)
      assert job.id == hd(jobs).id
    end

    test "success with filter be meta" do
      request_id = UUID.generate()
      job = insert(:job, type: "terminate", meta: %{"request_id" => request_id})
      insert(:job, type: "deactivate", meta: %{"request_id" => request_id})
      insert(:job, type: "terminate", meta: %{"request_id" => "123"})

      filter = [{:meta, nil, [{:request_id, :equal, request_id}]}, {:type, :equal, "terminate"}]
      assert {:ok, jobs} = RPC.search_jobs(filter, [desc: :inserted_at], {0, 10})
      assert is_list(jobs)
      assert 1 == length(jobs)
      assert job.id == hd(jobs).id
    end

    test "not found" do
      assert {:ok, []} == RPC.search_jobs()
    end
  end

  describe "get job" do
    test "success" do
      %{id: id} = insert(:job)
      assert {:ok, %{id: ^id}} = RPC.get_job(id)
    end

    test "not found" do
      refute RPC.get_job(UUID.generate())
    end
  end

  describe "get tasks" do
    test "search job tasks filtered by job.id" do
      terminate_job = insert(:job, type: "terminate")
      insert_list(3, :task, job: terminate_job)
      job = insert(:job, type: "merge")
      insert_list(5, :task, job: job)

      assert {:ok, tasks} = RPC.search_tasks([{:job_id, :equal, job.id}], [desc: :inserted_at], {0, 10})
      assert 5 == length(tasks)

      Enum.each(tasks, fn task ->
        assert job.id == task.job_id
      end)
    end
  end
end
