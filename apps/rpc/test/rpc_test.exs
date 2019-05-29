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

      Enum.each(jobs, fn job ->
        assert Map.has_key?(job, :tasks)
      end)
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
end
