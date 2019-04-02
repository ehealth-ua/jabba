defmodule Core.JobsTest do
  @moduledoc false

  use Core.ModelCase

  alias Core.Job
  alias Core.Jobs

  @test_callback {"test", Test, :run, []}

  describe "create new job" do
    test "success with minimum data" do
      data = %{
        type: "test",
        callback: @test_callback
      }

      job = Jobs.create(data)
    end
  end

  describe "process job" do
    setup do
      {:ok, job: insert(:job)}
    end

    test "result is map", %{job: job} do
      Jobs.processed(job, %{"success" => true})

      db_job = Jobs.get_by(id: job.id)
      assert Job.status(:processed) == db_job.status
    end
  end
end
