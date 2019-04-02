defmodule Core.Kafka.ProducerBehaviour do
  @moduledoc false

  @callback publish_job(event :: binary) :: :ok | {:error, reason :: term}
end
