defmodule Seeder do
  @moduledoc """
    Script for populating the database. You can run it as:
      iex> mix run priv/repo/seeder.ex

    Inside the script, you can read and write to any of your
    repositories directly:
      iex> Core.Repo.insert!(%Core.Job{})
  """
  alias Core.Repo
  alias Core.Job

  def seed do
    [{%Job{}, "/jobs.json"}]
    |> Enum.each(&seed_file/1)
  end

  defp seed_file({struct, file}) do
    file
    |> prepare_structs(struct)
    |> Enum.map(&insert_or_update!/1)
  end

  defp prepare_structs("/jobs.json" = file, struct) do
    file
    |> seed_file_path()
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&hydrate_struct(&1, struct))
  end

  defp hydrate_struct(json, struct) do
    data = Jason.decode!(json, keys: :atoms)
    %{
      ended_at: %{"$date": ended_at},
      started_at: %{"$date": inserted_at},
      status: status,
      type: type,
      result: result,
      result_size: result_size
    } = data

    attributes = Map.merge(data, %{
      status: map_status(status),
      type: map_type(type),
      result: result |> String.slice(0, result_size) |> Jason.decode!(),
      strategy: Job.strategy(:sequentially),
      inserted_at: add_microseconds(inserted_at),
      updated_at: add_microseconds(inserted_at),
      ended_at: add_microseconds(ended_at)
    })

    struct(struct, attributes)
  end

  defp add_microseconds(timestamp) do\
    {:ok, datetime, _} = timestamp
    |> String.replace("Z", "000Z")
    |> DateTime.from_iso8601()
    datetime
  end

  defp map_type(200), do: "merge_legal_entities"
  defp map_type(300), do: "legal_entity_deactivation"

  defp map_status(0), do: Job.status(:pending)
  defp map_status(1), do: Job.status(:processed)
  defp map_status(2), do: Job.status(:failed)
  defp map_status(3), do: Job.status(:failed)

  defp insert_or_update!(schema) do
    Repo.insert!(
      schema,
      on_conflict: prepare_on_conflict(schema),
      conflict_target: :id
    )
  end

  defp prepare_on_conflict(schema) do
    not_for_update = ~w(id inserted_at updated_at)a

    update =
      :fields
      |> schema.__struct__.__schema__()
      |> Enum.reject(fn elem -> elem in not_for_update end)
      |> Enum.map(fn field ->
        {field, Map.get(schema, field)}
      end)

    [set: update]
  end

  defp seed_file_path(file) do
    :core
    |> Application.app_dir("priv/repo/seeds")
    |> Kernel.<>(file)
  end
end

Seeder.seed()
