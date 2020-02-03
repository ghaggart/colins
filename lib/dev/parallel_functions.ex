defmodule Colins.Dev.ParallelFunctions do

  def pmap(collection, func) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(&Task.await/1)
  end

  # Colllection of edges: map with edge_id => function
  def run_edge_functions(collection_of_edges) do

      #collection_of_edges

      IO.inspect(collection_of_edges)



      #|> Enum.map()

  end
end