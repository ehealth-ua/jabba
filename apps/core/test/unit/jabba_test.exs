defmodule Core.JabbaTest do
  @moduledoc false

  use Core.ModelCase
  alias Core.Kafka.TaskProcessor
  alias Core.Job
  alias Core.Jobs
  alias Ecto.UUID

  @strategy_concurrent Job.strategy(:concurrent)
  @task %{
    name: "test task",
    callback: {"test", Test, :run, [:some, %{arguments: "for"}, [:callback]]}
  }

  describe "create job with sequentially process strategy" do
    test "successfully with empty meta" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)

      assert {:ok, %Job{id: id}} = Jabba.run(@task, "test")

      assert %Job{} = job = Jobs.get_job_by(id: id)
      assert "test" == job.type
      assert Job.status(:pending) == job.status
    end

    test "successfully when meta is map" do
      expect(KafkaMock, :publish_task, fn _ -> :ok end)
      request_id = UUID.generate()

      opts = [meta: %{request_id: request_id}, name: "with-meta"]
      assert {:ok, %Job{id: id}} = Jabba.run(@task, "test", opts)

      assert %Job{} = job = Jobs.get_job_by(id: id)
      assert "with-meta" == job.name
      assert "test" == job.type
      assert Job.status(:pending) == job.status
      assert %{"request_id" => request_id} == job.meta
    end

    test "with invalid meta type" do
      Jabba.run(@task, "test", meta: "invalid type")
    end

    test "successfully with many tasks and consume" do
      request_id = UUID.generate()
      id = UUID.generate()

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
        assert [%{legal_entity_id: id}] == arguments

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

      tasks = [
        %{name: "Deactivate division", callback: {"ehealth", Test, :deactivate_division, [{11.2222, 22.3333}]}},
        %{name: "Deactivate employee", callback: {"mpi", Test, :deactivate_employee, [%{legal_entity_id: id}]}},
        %{name: "Deactivate declarations", callback: {"ops", Test, :deactivate_declarations, [[code: "AB2211II"]]}}
      ]

      assert {:ok, %Job{id: id}} = Jabba.run(tasks, "deactivate-le", opts)

      assert %Job{} = job = Jobs.get_job_by([id: id], :preload)
      assert "with many tasks" == job.name
      assert "deactivate-le" == job.type
      assert Job.status(:processed) == job.status
      assert job.ended_at
      assert %{"request_id" => request_id} == job.meta

      # tasks
      assert is_list(job.tasks)
      assert 3 = length(job.tasks)

      Enum.each(job.tasks, fn task ->
        assert Job.status(:processed) == task.status
        assert task.ended_at
      end)
    end
  end

  describe "create job with concurrent process strategy" do
    test "successfully with callback" do
      id = UUID.generate()

      expect(KafkaMock, :publish_tasks, fn tasks ->
        Enum.each(tasks, fn task_id ->
          task = Jobs.get_task_by(id: task_id)
          assert 0 == task.priority
          TaskProcessor.consume(task_id)
        end)

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
        assert [%{legal_entity_id: id}] == arguments

        {:ok, {:ok, :deactivated}}
      end)

      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "ops" == basename
        assert Test == module
        assert :deactivate_declarations == function
        assert [[code: "AB2211II"]] == arguments

        {:ok, :ok}
      end)

      expect(RPCClientMock, :run, fn basename, module, function, arguments ->
        assert "ehealth" == basename
        assert Test == module
        assert :job_processed == function
        assert [%{some: "arg"}, job_additional_arg] = arguments

        Enum.each(~w(job_id status meta)a, fn field ->
          assert Map.has_key?(job_additional_arg, field)
        end)

        {:ok, :ok}
      end)

      opts = [
        name: "Concurrent job",
        strategy: @strategy_concurrent,
        callback: {"ehealth", Test, :job_processed, [%{some: "arg"}]}
      ]

      tasks = [
        %{name: "Deactivate division", callback: {"ehealth", Test, :deactivate_division, [{11.2222, 22.3333}]}},
        %{name: "Deactivate employee", callback: {"mpi", Test, :deactivate_employee, [%{legal_entity_id: id}]}},
        %{name: "Deactivate declarations", callback: {"ops", Test, :deactivate_declarations, [[code: "AB2211II"]]}}
      ]

      assert {:ok, %Job{id: id}} = Jabba.run(tasks, "deactivate-le", opts)

      assert %Job{} = job = Jobs.get_job_by([id: id], :preload)
      assert "Concurrent job" == job.name
      assert "deactivate-le" == job.type
      assert Job.status(:processed) == job.status
      assert job.ended_at
      refute job.meta

      # tasks
      assert is_list(job.tasks)
      assert 3 = length(job.tasks)

      Enum.each(job.tasks, fn task ->
        assert Job.status(:processed) == task.status
        assert task.ended_at
      end)
    end
  end
end
