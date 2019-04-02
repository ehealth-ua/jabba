defmodule Core.Kafka.Producer do
  @moduledoc false

  alias Core.Kafka.ProducerBehaviour
  alias Kaffe.Producer
  require Logger

  @behaviour ProducerBehaviour
  @topic "jobs"
  @partition 0

  def publish_job(job_id) when is_binary(job_id) do
    with :ok <- Producer.produce_sync(@topic, @partition, "", job_id) do
      Logger.debug(fn -> "Published job with id #{job_id} to kafka" end)
      :ok
    end
  end
end
