defmodule Core.Kafka.Producer do
  @moduledoc false

  alias Core.Kafka.ProducerBehaviour
  alias Kaffe.Producer
  require Logger

  @behaviour ProducerBehaviour
  @topic "jobs"
  @partition 0

  def publish_task(id) when is_binary(id) do
    with :ok <- Producer.produce_sync(@topic, @partition, "", id) do
      Logger.info(fn -> "Published task with id `#{id}` to kafka" end)
      :ok
    end
  end

  def publish_tasks(ids) when is_list(ids), do: Enum.each(ids, &publish_task/1)
end
