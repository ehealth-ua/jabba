use Mix.Config

config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "jabba_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10
