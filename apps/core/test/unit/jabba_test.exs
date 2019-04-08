defmodule Core.JabbaTest do
  @moduledoc false

  use Core.ModelCase
  alias Core.Kafka.TaskProcessor
  alias Core.Job
  alias Core.Jobs
  alias Ecto.UUID

  @test_callback {"test", Test, :run, [:some, %{arguments: "for"}, [:callback]]}

  describe "create job with sequentially process strategy" do
    test "successfully with empty meta" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)

      assert {:ok, %Job{id: id}} = Jabba.run(@test_callback, "test")

      assert %Job{} = job = Jobs.get_by(id: id)
      assert "test" == job.type
      assert Job.status(:pending) == job.status
    end

    test "successfully when meta is map" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)
      request_id = UUID.generate()

      opts = [meta: %{request_id: request_id}, name: "with-meta"]
      assert {:ok, %Job{id: id}} = Jabba.run(@test_callback, "test", opts)

      assert %Job{} = job = Jobs.get_by(id: id)
      assert "with-meta" == job.name
      assert "test" == job.type
      assert Job.status(:pending) == job.status
      assert %{"request_id" => request_id} == job.meta
    end

    test "with invalid meta type" do
      Jabba.run(@test_callback, "test", meta: "invalid type")
    end

    test "successfully with many tasks and consume" do
      request_id = UUID.generate()
      legal_entity_id = UUID.generate()

      expect(KafkaMock, :publish_task, fn task_id ->
        task = Jobs.get_task_by(id: task_id)
        assert 1 == task.priority
        TaskProcessor.consume(task.id)
        :ok
      end)

      expect(KafkaMock, :publish_task, fn task_id ->
        task = Jobs.get_task_by(id: task_id)
        assert 2 == task.priority
        TaskProcessor.consume(task.id)
        :ok
      end)

      expect(KafkaMock, :publish_task, fn task_id ->
        task = Jobs.get_task_by(id: task_id)
        assert 3 == task.priority
        TaskProcessor.consume(task.id)
        :ok
      end)

      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "ehealth" == basename
        assert Test == module
        assert :deactivate_division == function
        assert [{11.2222, 22.3333}] == arguments

        {:ok, {:ok, :deactivated}}
      end)

      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "mpi" == basename
        assert Test == module
        assert :deactivate_employee == function
        assert [%{legal_entity_id: legal_entity_id}] == arguments

        {:ok, {:ok, :deactivated}}
      end)

      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "ops" == basename
        assert Test == module
        assert :deactivate_declarations == function
        assert [[code: "AB2211II"]] == arguments

        {:ok, :ok}
      end)

      opts = [meta: %{request_id: request_id}, name: "with many tasks"]

      callback = [
        {"ehealth", Test, :deactivate_division, [{11.2222, 22.3333}]},
        {"mpi", Test, :deactivate_employee, [%{legal_entity_id: legal_entity_id}]},
        {"ops", Test, :deactivate_declarations, [[code: "AB2211II"]]}
      ]

      assert {:ok, %Job{id: id}} = Jabba.run(callback, "deactivate-le", opts)

      assert %Job{} = job = Jobs.get_by(id: id)
      assert "with many tasks" == job.name
      assert "deactivate-le" == job.type
      assert Job.status(:pending) == job.status
      assert %{"request_id" => request_id} == job.meta
    end
  end
end
