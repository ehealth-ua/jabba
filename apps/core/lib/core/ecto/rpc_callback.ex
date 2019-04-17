defmodule Core.Ecto.RPCCallback do
  @moduledoc """
  Defines Ecto type for RPC callback attributes
  """

  @behaviour Ecto.Type

  @type t :: {binary, atom, atom, list}

  defguard is_callback(callback)
           when is_tuple(callback) and tuple_size(callback) == 4 and is_binary(elem(callback, 0)) and
                  is_atom(elem(callback, 1)) and is_atom(elem(callback, 2)) and is_list(elem(callback, 3))

  def type, do: :binary

  def cast(callback) when is_callback(callback), do: {:ok, :erlang.term_to_binary(callback)}
  def cast(_), do: :error

  def load(string) when is_binary(string), do: {:ok, :erlang.binary_to_term(string)}

  def dump(string) when is_binary(string), do: {:ok, string}
end
