require Logger

defmodule Colins.Solvers.Euler do
    @moduledoc false


    def solve(solver_id,edge_id,edge_definition,node_data,_step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

        ##IO.inspect("Solver starting")

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

      output_var= Colins.Solvers.Utils.get_output_var(outputs)

      number_of_inputs = length(Map.values(inputs))

      processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
        Map.put(acc,input_name,Map.get(node_data,node_id))
      end)

      Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

      IO.inspect(processed_inputs)

      # Call the lambda with the new data
      # k1 = h * dydx(x0, y)
      lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

      IO.inspect(processed_inputs)
      IO.inspect(lambda_output)

      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k1: " <> inspect(lambda_output))

      returned_values = Map.put(%{},"k1",lambda_output)

      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)


    end

end