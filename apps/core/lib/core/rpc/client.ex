defmodule Core.RPC.Client do
  @moduledoc false

  use KubeRPC.Client, :core

  import Core.Ecto.RPCCallback, only: [is_callback: 1]

  require Logger

  @rpc_client Application.get_env(:core, :rpc_client)

  def safe_callback(callback) when is_callback(callback) do
    case apply(@rpc_client, :run, Tuple.to_list(callback)) do
      {:ok, :ok} ->
        {:ok, :ok}

      {:ok, result} ->
        result

      err ->
        Logger.warn(fn -> "Invalid RPC call with: `#{inspect(err)}`" end)
        err
    end
  rescue
    err -> {:rescued, err}
  end
end
