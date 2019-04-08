defmodule Core.Kafka.ProducerBehaviour do
  @moduledoc false

  @callback publish_task(job_id :: binary) :: :ok | {:error, reason :: term}
end
