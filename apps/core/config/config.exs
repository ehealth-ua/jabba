use Mix.Config

config :core,
  env: Mix.env(),
  namespace: Core,
  ecto_repos: [Core.Repo],
  rpc_worker: Core.Rpc.Worker,
  kafka: [
    producer: Core.Kafka.Producer
  ],
  kaffe_consumer: [
    endpoints: [localhost: 9092],
    topics: ["jobs"],
    consumer_group: "jobs_group",
    message_handler: Core.Jabba
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
