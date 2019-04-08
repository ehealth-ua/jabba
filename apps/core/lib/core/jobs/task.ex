defmodule Core.Task do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Ecto.RPCCallback
  alias Core.Job
  alias Ecto.UUID

  @status_new "NEW"
  @status_pending "PENDING"
  @status_consumed "CONSUMED"
  @status_processed "PROCESSED"
  @status_failed "FAILED"
  @status_rescued "RESCUED"
  @status_aborted "ABORTED"

  @primary_key {:id, UUID, autogenerate: true}
  schema "tasks" do
    field(:callback, RPCCallback)
    field(:priority, :integer)
    field(:status, :string, default: @status_new)
    field(:result, :map)
    field(:ended_at, :utc_datetime_usec)

    belongs_to(:job, Job, type: UUID)

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(callback)a
  @optional ~w(priority result status ended_at)a

  def changeset(%__MODULE__{} = task, params) do
    task
    |> cast(params, @optional ++ @required)
    |> validate_required(@required)
    |> validate_inclusion(:status, statuses())
  end

  def status(:new), do: @status_new
  def status(:pending), do: @status_pending
  def status(:consumed), do: @status_consumed
  def status(:processed), do: @status_processed
  def status(:failed), do: @status_failed
  def status(:rescued), do: @status_rescued
  def status(:aborted), do: @status_aborted

  def statuses,
    do: [
      @status_new,
      @status_pending,
      @status_consumed,
      @status_processed,
      @status_failed,
      @status_rescued
    ]

  def statuses(:failed), do: [@status_failed, @status_rescued]
end
