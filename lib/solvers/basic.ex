require Logger

defmodule Colins.Solvers.Basic do
    @moduledoc false

    @doc "Get the timestep solver function sequence. Keys map to function names. Executed sequentially."
    def get_solve_sequence() do

        [ :solve ]

    end

    def solve(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,mesh_size,local_error_maximum) do

        inputs = Map.get(edge_definition,"inputs")
        outputs = Map.get(edge_definition,"outputs")

        output_var= Colins.Solvers.Utils.get_output_var(outputs)

        number_of_inputs = length(Map.values(inputs))

        processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
            Map.put(acc,input_name,Map.get(node_data,node_id))
        end)

        Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

        # Call the lambda with the new data
        # k1 = h * dydx(x0, y)
        lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs)

        Colins.Solvers.Utils.send_to_nodes(lambda_output,outputs,Float.round(timepoint + step_size,11))

        Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,%{"lambda_output"=>lambda_output})

    end


end