defmodule Core.JobsTest do
  @moduledoc false

  use Core.ModelCase
  alias Core.Job
  alias Core.Jobs

  describe "search jobs" do
    test "filter by meta" do
      insert(:job, meta: %{merged_from_legal_entity: %{edrpou: "0987654321"}})
      insert(:job, meta: %{merged_from_legal_entity: %{edrpou: "1234567890"}})

      %{id: id} =
        insert(:job,
          meta: %{
            merged_from_legal_entity: %{edrpou: "1234567890"},
            merged_to_legal_entity: %{is_active: true}
          }
        )

      filter = [
        {:type, :equal, "test"},
        {:meta, :jsonb, {["merged_from_legal_entity", "edrpou"], "1234567890"}}
      ]

      assert {:ok, jobs} = Jobs.search_jobs(filter)
      assert 2 == length(jobs)

      filter = [
        {:type, :equal, "test"},
        {:meta, :jsonb, {["merged_from_legal_entity", "edrpou"], "1234567890"}},
        {:meta, :jsonb, {["merged_to_legal_entity", "is_active"], true}}
      ]

      assert {:ok, jobs} = Jobs.search_jobs(filter)
      assert 1 == length(jobs)
      assert id == hd(jobs).id
    end
  end
end
