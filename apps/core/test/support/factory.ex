defmodule Core.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Core.Repo

  alias Core.Job
  alias Ecto.UUID

  def job_factory do
    %Job{
      type: "test",
      callback: :erlang.term_to_binary({"test", TestRpc, :run, []}),
      meta: %{},
      status: Job.status(:pending)
    }
  end
end
