defmodule Brewery do
  @moduledoc """
  Transform Erlang's [Abstract Format](http://erlang.org/doc/apps/erts/absform.html) to LLVM IR then to native code.
  """

  @doc """
  Compile `:beam_lib.chunks`'s abstract code to native code

  ```elixir
  beam_code |> parse_beam!() |> compile(compile_path) |> File.write("./out")
  ```
  """
  def compile({_version, ast}, compile_path) do
    Enum.each(ast, &case &1 do
      {:function, _line, name, arity, clauses} ->
        IO.inspect("#{name}/#{arity}")
        IO.inspect(clauses)
        IO.puts "\n"
      other -> other
    end)

    {:error, "brewery not finished"}
  end

end
