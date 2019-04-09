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

    test "successfully with one task" do
    end

    test "successfully with many tasks" do
    end
  end

  describe "search jobs" do
    test "success with filter params" do
      job = insert(:job, type: "terminate")
      insert_list(2, :job, type: "deactivate")
      insert_list(4, :job, type: "terminate")

      assert {:ok, jobs} = RPC.search_jobs([{:type, :equal, "terminate"}], [desc: :inserted_at], {0, 10})
      assert is_list(jobs)
      assert 5 == length(jobs)
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
      assert {:error, {:not_found, "Job not found"}} = RPC.get_job(UUID.generate())
    end
  end
end
