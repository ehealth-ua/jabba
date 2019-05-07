defmodule Core.Filters.Base do
  @moduledoc false

  use EctoFilter
  use EctoFilter.Operators.JSON

  # ToDo: hardcoded for meta with two embed objects. Must be parsed dynamically
  def apply(query, {field, :jsonb, {[first_object_field, second_object_field], value}}, _, _) do
    where(query, [j], fragment("?->?->? = ?", field(j, ^field), ^first_object_field, ^second_object_field, ^value))
  end

  def apply(query, operation, type, context), do: super(query, operation, type, context)

  defoverridable EctoFilter
end
