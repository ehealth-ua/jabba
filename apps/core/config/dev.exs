use Mix.Config

config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  database: "jabba_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10
