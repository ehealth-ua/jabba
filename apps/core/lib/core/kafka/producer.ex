defmodule Core.Kafka.Producer do
  @moduledoc false

  alias Core.Kafka.ProducerBehaviour
  alias Kaffe.Producer
  require Logger

  @behaviour ProducerBehaviour
  @topic "jobs"
  @partition 0

  def publish_job(event) when is_binary(event) do
    with :ok <- Producer.produce_sync(@topic, @partition, "", event) do
      Logger.info("Published event #{inspect(event)} to kafka")
      :ok
    end
  end
end
