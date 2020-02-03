defmodule Brewery.Shim do
  defmacro __using__(_opts) do
    quote do: @is_brewery_shim true
  end
end
