defmodule Core.Job do
  @moduledoc """
  Job schema
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Task
  alias Ecto.UUID

  @type t :: %{
          id: binary,
          type: binary,
          status: binary,
          callback: RPCCallback.t(),
          meta: map,
          result: map,
          ended_at: DateTime,
          inserted_at: DateTime,
          updated_at: DateTime
        }

  @status_pending "PENDING"
  @status_processed "PROCESSED"
  @status_failed "FAILED"

  @strategy_sequentially "SEQUENTIALLY"

  @primary_key {:id, UUID, autogenerate: true}
  schema "jobs" do
    field(:name, :string)
    field(:type, :string)
    field(:strategy, :string)
    field(:status, :string, default: @status_pending)
    field(:meta, :map)
    field(:ended_at, :utc_datetime_usec)

    has_many(:tasks, Task)

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(type strategy)a
  @optional ~w(name meta status ended_at)a

  def changeset(%__MODULE__{} = job, params) do
    job
    |> cast(params, @optional ++ @required)
    |> cast_assoc(:tasks, with: &Task.changeset/2)
    |> validate_required(@required)
    |> validate_length(:name, max: 128)
    |> validate_inclusion(:status, statuses())
    |> validate_inclusion(:strategy, strategies())
  end

  def statuses, do: [@status_pending, @status_processed, @status_failed]

  def status(:pending), do: @status_pending
  def status(:processed), do: @status_processed
  def status(:failed), do: @status_failed

  def strategies, do: [@strategy_sequentially]

  def strategy(:sequentially), do: @strategy_sequentially
end
