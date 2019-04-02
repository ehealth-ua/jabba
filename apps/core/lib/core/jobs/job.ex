defmodule Core.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Ecto.RpcCallback
  alias Ecto.UUID

  @status_pending "PENDING"
  @status_consumed "CONSUMED"
  @status_processed "PROCESSED"
  @status_failed "FAILED"
  @status_rescued "RESCUED"

  @primary_key {:id, UUID, autogenerate: true}
  schema "jobs" do
    field(:type, :string)
    field(:callback, RpcCallback)
    field(:meta, :map)
    field(:status, :string, default: @status_pending)
    field(:result, :map)
    field(:ended_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(type callback)a
  @optional ~w(meta status result ended_at)a

  def changeset(%__MODULE__{} = job, params) do
    job
    |> cast(params, @optional ++ @required)
    |> validate_required(@required)
  end

  def status(:pending), do: @status_pending
  def status(:consumed), do: @status_consumed
  def status(:processed), do: @status_processed
  def status(:failed), do: @status_failed
  def status(:rescued), do: @status_rescued
end
