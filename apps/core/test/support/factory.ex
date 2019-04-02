defmodule Core.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Core.Repo

  alias Core.Job

  def job_factory do
    %Job{
      type: "test",
      callback: {"test", TestRpc, :run, []},
      meta: %{},
      status: Job.status(:pending)
    }
  end
end
