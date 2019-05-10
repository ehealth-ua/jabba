defmodule Core.JobsTest do
  @moduledoc false

  use Core.ModelCase
  alias Core.Jobs

  describe "search jobs" do
    test "filter by meta" do
      insert(:job, meta: %{merged_from_legal_entity: %{edrpou: "0987654321"}})
      insert(:job, meta: %{merged_from_legal_entity: %{edrpou: "1234567890"}})

      insert(:job,
        meta: %{
          merged_from_legal_entity: %{edrpou: "1234567890", is_active: false},
          merged_to_legal_entity: %{is_active: true}
        }
      )

      %{id: id} =
        insert(:job,
          meta: %{
            merged_from_legal_entity: %{edrpou: "1234567890", is_active: true},
            merged_to_legal_entity: %{is_active: true}
          }
        )

      filter = [
        {:type, :equal, "test"},
        {:meta, nil, [{:merged_from_legal_entity, nil, [{:edrpou, :equal, "1234567890"}]}]}
      ]

      assert {:ok, jobs} = Jobs.search_jobs(filter)
      assert 3 == length(jobs)

      filter = [
        {:type, :equal, "test"},
        {:meta, nil,
         [
           {:merged_to_legal_entity, nil, [{:is_active, :equal, true}]},
           {:merged_from_legal_entity, nil, [{:edrpou, :equal, "1234567890"}, {:is_active, :equal, true}]}
         ]}
      ]

      assert {:ok, jobs} = Jobs.search_jobs(filter)
      assert 1 == length(jobs)
      assert id == hd(jobs).id
    end
  end
end
