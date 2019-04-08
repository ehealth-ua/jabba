use Mix.Config

# Configuration for test environment
System.put_env("MAX_PERSONS_RESULT", "2")

config :ex_unit, capture_log: true

# Print only warnings and errors during test
config :logger, level: :warn

config :core,
  ecto_repos: [Core.Repo],
  rpc_client: RPCClientMock,
  kafka: [
    producer: KafkaMock
  ]

# Configure your database
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  database: "jabba_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000
