#!/bin/sh
# `pwd` should be /opt/rpc
APP_NAME="rpc"

if [ "${DB_MIGRATE}" == "true" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/$APP_NAME command Elixir.RPC.ReleaseTasks migrate
fi;

if [ "${DB_SEED}" == "true" ]; then
  echo "[WARNING] Seeding database!"
  ./bin/$APP_NAME command Elixir.RPC.ReleaseTasks seed
fi;
