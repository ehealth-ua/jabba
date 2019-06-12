defmodule Core.Repo.Migrations.AddJobCallback do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:callback, :binary, null: true)
    end
  end
end
