defmodule Core.Repo.Migrations.CreateJob do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :text, null: false)
      add(:status, :text, null: false)
      add(:callback, :binary, null: false)
      add(:meta, :map)
      add(:result, :map)
      add(:ended_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end
  end
end
