defmodule Core.Kafka.ProducerBehaviour do
  @moduledoc false

  @callback publish_job(job_id :: binary) :: :ok | {:error, reason :: term}
end
