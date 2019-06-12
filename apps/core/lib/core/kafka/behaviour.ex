defmodule Core.Kafka.ProducerBehaviour do
  @moduledoc false

  @callback publish_task(id :: binary) :: :ok | {:error, reason :: term}
  @callback publish_tasks(ids :: list) :: :ok | {:error, reason :: term}
end
