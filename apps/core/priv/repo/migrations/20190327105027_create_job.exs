defmodule Core.Repo.Migrations.CreateJob do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :text)
      add(:type, :text, null: false)
      add(:strategy, :text, null: false)
      add(:status, :text, null: false)
      add(:meta, :map)
      add(:ended_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
