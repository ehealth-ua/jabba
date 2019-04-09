defmodule Core.Repo.Migrations.CreateTask do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:callback, :binary, null: false)
      add(:name, :text)
      add(:priority, :smallint, null: false, default: 0)
      add(:result, :map)
      add(:status, :text, null: false)
      add(:job_id, references(:jobs, type: :uuid, on_delete: :restrict))
      add(:ended_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end
  end
end
