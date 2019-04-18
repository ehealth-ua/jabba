use Mix.Config

config :core, Core.Repo,
  username: {:system, :string, "DB_USER"},
  password: {:system, :string, "DB_PASSWORD"},
  database: {:system, :string, "DB_NAME"},
  hostname: {:system, :string, "DB_HOST"},
  port: {:system, :integer, "DB_PORT"},
  pool_size: {:system, :integer, "POOL_SIZE", 10},
  timeout: :infinity

config :core,
  kaffe_consumer: [
    endpoints: {:system, :string, "KAFKA_BROKERS"},
    topics: ["jobs"],
    consumer_group: "jobs_group",
    message_handler: Core.Kafka.TaskProcessor
  ]

config :kaffe,
  producer: [
    endpoints: {:system, :string, "KAFKA_BROKERS"},
    topics: ["jobs"]
  ]
