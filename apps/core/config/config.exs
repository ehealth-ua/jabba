use Mix.Config

config :core,
  env: Mix.env(),
  namespace: Core,
  ecto_repos: [Core.Repo],
  rpc_client: Core.RPC.Client,
  kafka: [
    producer: Core.Kafka.Producer
  ],
  kaffe_consumer: [
    endpoints: [localhost: 9092],
    topics: ["jobs"],
    consumer_group: "jobs_group",
    message_handler: Core.Kafka.TaskProcessor
  ]

config :logger_json, :backend,
  formatter: EhealthLogger.Formatter,
  metadata: :all

config :logger,
  backends: [LoggerJSON],
  level: :info

config :kaffe,
  producer: [
    endpoints: [localhost: 9092],
    topics: ["jobs"]
  ]

config :core,
  topologies: [
    k8s_il: [
      strategy: Elixir.Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "ehealth",
        kubernetes_selector: "app=api",
        kubernetes_namespace: "il",
        polling_interval: 10_000
      ]
    ]
  ]

import_config "#{Mix.env()}.exs"
