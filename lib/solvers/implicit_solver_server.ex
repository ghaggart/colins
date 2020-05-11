require Logger

# The implicit solver server works diffrently to the explicit solver server.
# The explicit solver uses a fixed number of sub steps to calculate the new values.
# The implicit solver uses the newton-raphson method to iteratively calculate the values to minimise a function
# Ie where it passes zero. This means there is dynamic number of sub steps (the number required to reach zero,
# with a maximum of 20 per step).
defmodule Colins.Solvers.ImplicitSolverServer do
  @moduledoc false

  use GenServer

  def start_link(solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum) do

    GenServer.start_link(__MODULE__,[solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum], [name: solver_id])
  end

  def init([solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum]) do

    {solver_module_name,_} = Code.eval_string("Colins.Solvers." <> solver_type)
    solver_subfunction_sequence = apply(solver_module_name,:get_solve_sequence,[])

    all_input_nodes = Enum.reduce(edge_definitions,[],fn({_edge_id,edge_definition},acc) ->
      Enum.concat(acc,Map.values(Map.get(edge_definition,"inputs")))
    end)
    all_output_nodes = Enum.reduce(edge_definitions,[],fn({_edge_id,edge_definition},acc) ->
      Enum.concat(acc,Map.keys(Map.get(edge_definition,"outputs")))
    end)
    unique_dynamic_nodes = Enum.uniq(Enum.concat(all_input_nodes,all_output_nodes))

    state = %{  "solver_id" => solver_id,
                "solver_type" => solver_type,
                "partition_id" => partition_id,
                "solver_module_name" => solver_module_name,
                "solver_subfunction_sequence" => solver_subfunction_sequence,
                "edge_definitions"=>edge_definitions,
                "newton_raphson_edge_definitions"=>%{},
                "unique_dynamic_nodes"=>unique_dynamic_nodes,
                "current_subfunction_step"=> List.first(solver_subfunction_sequence),
                "current_timestep_errors"=>%{},
                "current_step_size"=>nil,
                "current_timepoint"=>nil,
                "running_edges"=>%{},
                "step_dynamic_node_cache"=>%{},
                "step_residuals_sum"=>0.0,
                "step_number_of_nr_iterations"=>0,
                "step_calculated_data"=>%{},
                "step_converged_edges"=>[],
                "local_error_maximum"=>local_error_maximum,
                "local_error_minimum"=>local_error_minimum,
                "mesh_size"=>mesh_size,
                "max_number_of_nr_iterations"=>1000
    }

    {:ok, state}

  end

  def run_edges(solver_id,timepoint,step_size) do

    GenServer.cast(solver_id,{:run_edges,timepoint,step_size})

  end

  def write_edges(solver_id) do

    GenServer.cast(solver_id,:write_edges)

  end

  def notify_edge_complete(solver_id,edge_id,returned_data,subfunction_type \\ nil) do

    GenServer.cast(solver_id,{:notify_edge_complete,edge_id,returned_data,subfunction_type})

  end

  def handle_cast({:run_edges,timepoint,step_size},state) do

    # 1. If no edge definitions, get them and store them.

    Logger.debug(inspect(state))

    state = Map.put(state,"current_step_size",step_size)
    state = Map.put(state,"current_timepoint",timepoint)
    state = Map.put(state,"optimal_step_sizes",%{})

    # 2. Run the subfunction sequence

    {:noreply,run_subfunction_sequence(Map.get(state,"current_subfunction_step"),state)}

  end

  def handle_cast(:write_edges,state) do

    Enum.map(Map.get(state,"edge_definitions"),fn({edge_id,_}) ->

      Colins.Edges.EdgeData.write_to_file(edge_id)
    end)

    {:noreply,state}

  end

  def parse_returned_values(state,edge_id,returned_data,nil) do

    # 2. Add the returned_data to the step_calculated_data map.
    step_calculated_data = Map.get(state,"step_calculated_data")

    edge_step_calculated_data = case Map.has_key?(step_calculated_data,edge_id) do
      true -> Map.get(step_calculated_data,edge_id)
      false -> %{}
    end

    #edge_step_calculated_data = Map.get(step_calculated_data,edge_id)
    edge_step_calculated_data = Enum.reduce(returned_data,edge_step_calculated_data,fn({key,value},acc) ->
      Map.put(acc,key,value)
    end)

    #step_calculated_data = Map.put(step_calculated_data,edge_id,edge_step_calculated_data)
    Map.put(state,"step_calculated_data",Map.put(step_calculated_data,edge_id,edge_step_calculated_data))

  end

  def parse_returned_values(state,edge_id,returned_data,:build_newton_raphson_edge_definitions) do

    # Get and attach the returned values to the map using edge_id as the key
    newton_raphson_edge_definitions = Map.put(Map.get(state,"newton_raphson_edge_definitions"),edge_id,returned_data)

    Map.put(state,"newton_raphson_edge_definitions",newton_raphson_edge_definitions)

  end

  def parse_returned_values(state,edge_id,returned_data,:run_newton_raphson) do

    state = parse_returned_values(state,edge_id,returned_data,nil)
    state = Map.put(state,"step_residuals_sum",Map.get(state,"step_residuals_sum") + Map.get(returned_data,"value_of_F"))

    # Mark them as converged
    state = case Map.has_key?(returned_data,"result_has_converged") do
        true -> converged_edges = Map.get(state,"step_converged_edges")
                Map.put(state,"step_converged_edges",[ edge_id | converged_edges ])
        false -> state
    end

  end

  # When an edge completes, take the returned_data and add it to the step_calculated_data map.
  # step_calculated_data = {edge_id => {"k1" => 0.121, "k2" => 0.322} }
  def handle_cast({:notify_edge_complete,edge_id,returned_data,subfunction_type},state) do

    Logger.debug("notify edge complete: " <> inspect(edge_id))

    # 1. Remove this edge from the running_edges
    running_edges = List.delete(Map.get(state,"running_edges"), edge_id)

    state = parse_returned_values(state,edge_id,returned_data,subfunction_type)

    current_subfunction_step = Map.get(state,"current_subfunction_step")
    solver_subfunction_sequence = Map.get(state,"solver_subfunction_sequence")
    next_subfunction_step = Enum.at(solver_subfunction_sequence,(Enum.find_index(solver_subfunction_sequence, fn(x) -> (x == current_subfunction_step) end) + 1))
    step_number_of_nr_iterations = Map.get(state,"step_number_of_nr_iterations")

  #  IO.inspect(current_subfunction_step)

    # 4. If more running edges, do nothing.
    #    If no more subfunction steps, complete timestep
    #    Else run the next subfunction step
    state = case {length(running_edges),current_subfunction_step,step_number_of_nr_iterations} do

      {a,_,_} when a > 0 -> Map.put(state,"running_edges",running_edges)

      {a,:complete,_} when a == 0 -> timestep_complete(state)

      {a,{:iterative,_function_name},b} when (a == 0 and b > 1) -> check_residuals(state)

      _ -> run_subfunction_sequence(current_subfunction_step,state)

    end

    {:noreply, state}

  end

  # Iterates over all the nodes and sends the data
  def send_completed_data_to_nodes(state) do

    step_calculated_data = Map.get(state,"step_calculated_data")
    timepoint = Map.get(state,"current_timepoint")
    step_size = Map.get(state,"current_step_size")
    Enum.map(Map.get(state,"edge_definitions"),fn({edge_id,edge_definition}) ->
      outputs = Map.get(edge_definition,"outputs")
      edge_step_calculated_data = Map.get(step_calculated_data,edge_id)
      Colins.Solvers.Utils.send_to_nodes(Map.get(edge_step_calculated_data,"previous_estimate"),outputs,Float.round((timepoint + step_size),11))
    end)

  end

  def check_residuals(state) do

   # IO.inspect("check_residuals")

    # This function checks whether the total residual value
    # (ie the difference from zero) is zero or close to zero.
    # If its not zero and less than max number of iterations:
    #      run another newton_raphson iteration
    # If its not zero and greater than max number of iterations:
    #     reduce the step size by a quarter (step_size * 0.25)
    # If it is zero, or within the error tolerance,
    #     set the current_subfunction_step to :complete, send the previous_estimate to the nodes, and complete the timestep.

    step_residuals_sum = Map.get(state,"step_residuals_sum")
    step_number_of_nr_iterations = Map.get(state,"step_number_of_nr_iterations")
    max_number_of_nr_iterations = Map.get(state,"max_number_of_nr_iterations")
    local_error_maximum = Map.get(state,"local_error_maximum")

    #IO.inspect(step_residuals_sum)
  #  IO.inspect(step_number_of_nr_iterations)
  #  IO.inspect(abs(step_residuals_sum))
  #  IO.inspect(Map.get(state,"step_calculated_data"))
  #  IO.inspect(max_number_of_nr_iterations)
  #  IO.inspect(local_error_maximum)
    step_calculated_data = Map.get(state,"step_calculated_data")

    step_converged_edges = Map.get(state,"step_converged_edges")

    number_of_step_converged_edges = length(Map.get(state,"step_converged_edges"))

    number_of_edges = length(Map.keys(Map.get(state,"edge_definitions")))

    #if e == f then all have converged

    state = case {abs(step_residuals_sum),local_error_maximum,step_number_of_nr_iterations,max_number_of_nr_iterations,number_of_step_converged_edges,number_of_edges} do

      #If step residuals sum is zero, or within the error tolerance,
      #   set the current_subfunction_step to :complete, send the previous_estimate to the nodes, and complete the timestep.
      {a,b,_,_,e,f} when (a == 0.0 or a <= b or e == f) ->  #IO.inspect(step_number_of_nr_iterations)
                                                            send_completed_data_to_nodes(state)
                                                            timestep_complete(Map.put(state,"current_subfunction_step",:complete))

      #If the step residual sum is not zero and is larger than the threshold and the number of iterations is larger than the max:
      {a,b,c,d,_,_} when (a != 0.0 and a >= b and c > d) -> Colins.Nodes.Controller.reset_timestep_data()
                                                            new_step_size = Map.get(state,"current_step_size") * 0.1
                                                            state = reset_timestep_data(Map.put(state,"current_step_size",new_step_size))
                                                            state = Map.put(state,"current_subfunction_step",List.first(Map.get(state,"solver_subfunction_sequence")))
                                                            Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete_with_step_size_change(new_step_size,Map.get(state,"partition_id"))
                                                            state # reset the step and make the step size smaller.

      # If the max number of iterations has not been met, run NR again
      {a,b,c,d,_,_,} when (a != 0.0 and a >= b and c <= d) -> run_subfunction_sequence(Map.get(state,"current_subfunction_step"),state) # reset the step and make the step size smaller.
    end

  end

  def build_newton_raphson_edge_definitions(state) do

  #  IO.inspect("build_newton_raphson_edge_definitions")

    solver_id = Map.get(state,"solver_id")
    solver_module_name = Map.get(state,"solver_module_name")
    solver_type = Map.get(state,"solver_type")

    running_edges = Enum.reduce(Map.get(state,"edge_definitions"),[],fn({edge_id,edge_definition},acc) ->
        spawn(solver_module_name,:build_newton_raphson_edge_definitions,[solver_id,edge_id,edge_definition])
        [ edge_id | acc ]
    end)

    state = Map.put(state,"running_edges",running_edges)
    solver_subfunction_sequence = Map.get(state,"solver_subfunction_sequence")
    current_subfunction_step = Map.get(state,"current_subfunction_step")
    next_subfunction_step = Enum.at(solver_subfunction_sequence,(Enum.find_index(solver_subfunction_sequence, fn(x) -> (x == current_subfunction_step) end) + 1))

    Map.put(state,"current_subfunction_step",next_subfunction_step)
  end

  # Spawn the processes to generate the newton raphson edge definitions
  # OR Run the next subfunction sequence
  def run_subfunction_sequence({:once,function_name},state) do

   # IO.inspect("run_subfunction_sequence({:once,function_name}")

    newton_raphson_edge_definitions = Map.get(state,"newton_raphson_edge_definitions")
    solver_subfunction_sequence = Map.get(state,"solver_subfunction_sequence")

    state = case map_size(newton_raphson_edge_definitions) do

        # Run this subfunction step. Calculate the edge definitions concurrently and return the data to here.
        0 -> build_newton_raphson_edge_definitions(state)
        # Else set the subfunction step to the next one and run the next subfunction step
        _ -> next_subfunction_step = Enum.at(solver_subfunction_sequence,(Enum.find_index(solver_subfunction_sequence, fn(x) -> (x == {:once,function_name}) end) + 1))
             run_subfunction_sequence(next_subfunction_step,Map.put(state,"current_subfunction_step",next_subfunction_step))

    end

  end

  # Create the node_data cache for the step. Using the timepoint values from the previous step.
  def generate_step_dynamic_node_cache(state,timepoint,step_size) do

   # IO.inspect("generate_step_dynamic_node_cache")

    step_dynamic_node_cache = Enum.reduce(Map.get(state,"unique_dynamic_nodes"),Map.get(state,"step_dynamic_node_cache"),fn(node_id,acc) ->
      node_data = case node_id do
        :timepoint -> timepoint
        _ -> Colins.Nodes.MasterNode.get_timepoint_data(node_id,timepoint)
      end
      Map.put(acc,node_id,node_data)
    end)
   # IO.inspect(step_dynamic_node_cache)

    step_dynamic_node_cache = Map.put(step_dynamic_node_cache,:timepoint,timepoint)
    state = Map.put(state,"step_dynamic_node_cache",step_dynamic_node_cache)

  end

  # Run a linear subfunction sequence - ie calculating the first estimate
  def run_subfunction_sequence({:linear,function_name},state) do

    IO.inspect("run_subfunction_sequence({:linear,function_name}")

    # 1. Get the step_dynamic_node_cache and set if not yet loaded
      # 2. Spawn the subfunction step with MFA and step_calculated_data (subfunction values ie k1)

    timepoint = Map.get(state,"current_timepoint")
    step_size = Map.get(state,"current_step_size")

    state = case map_size(Map.get(state,"step_dynamic_node_cache")) do
      0 -> generate_step_dynamic_node_cache(state,timepoint,step_size)
      _ -> state
    end
    step_dynamic_node_cache = Map.get(state,"step_dynamic_node_cache")

    solver_module_name = Map.get(state,"solver_module_name")
    solver_type = Map.get(state,"solver_type")
    solver_id = Map.get(state,"solver_id")
    local_error_maximum = Map.get(state,"local_error_maximum")
    mesh_size = Map.get(state,"mesh_size")
    step_calculated_data = Map.get(state,"step_calculated_data")

    # Spawn each edge process and populate the running_edges
    running_edges = Enum.reduce(Map.get(state,"edge_definitions"),[],fn({edge_id,edge_definition},acc) ->

      # 1. Get the edge dynamic node data
      node_data = Enum.reduce(Map.get(edge_definition,"inputs"),%{},fn({input_name,node_id},acc2) ->
        Map.put(acc2,node_id,Map.get(step_dynamic_node_cache,node_id))
      end)

      node_data = Enum.reduce(Map.get(edge_definition,"outputs"),node_data,fn({node_id,add_or_subtract},acc2) ->
        Map.put(acc2,node_id,Map.get(step_dynamic_node_cache,node_id))
      end)

      spawn(solver_module_name,function_name,[solver_id,edge_id,edge_definition,node_data,Map.get(step_calculated_data,edge_id),step_size,timepoint,mesh_size,local_error_maximum])

      [ edge_id | acc ]
    end)

    state = Map.put(state,"running_edges",running_edges)

    # Set the next subfunction
    solver_subfunction_sequence = Map.get(state,"solver_subfunction_sequence")
    subfunction_sequence_index = Enum.find_index(solver_subfunction_sequence, fn(x) -> (x == {:linear,function_name}) end)

    Map.put(state,"current_subfunction_step",Enum.at(solver_subfunction_sequence,(subfunction_sequence_index + 1)))

  end

  def run_subfunction_sequence({:iterative,function_name},state) do

    IO.inspect("run_subfunction_sequence({:iterative,function_name}")

    # 1. At the beginning of the step - check the sum of totals and how close they are to zero.
    # 2. If they are not close enough to zero, run the next iteration.

    step_calculated_data = Map.get(state,"step_calculated_data")

    # check the values here ("previous_estimate").

    step_dynamic_node_cache = Map.get(state,"step_dynamic_node_cache")
    timepoint = Map.get(state,"current_timepoint")
    step_size = Map.get(state,"current_step_size")

    #IO.inspect("here")
    # Build the step dynamic node cache
    state = case map_size(Map.get(state,"step_dynamic_node_cache")) do
      0 -> generate_step_dynamic_node_cache(state,timepoint,step_size)
      _ -> state
    end
    step_dynamic_node_cache = Map.get(state,"step_dynamic_node_cache")

    solver_module_name = Map.get(state,"solver_module_name")
    solver_type = Map.get(state,"solver_type")
    solver_id = Map.get(state,"solver_id")
    newton_raphson_edge_definitions = Map.get(state,"newton_raphson_edge_definitions")

    # Spawn each edge process and populate the running_edges
    running_edges = Enum.reduce(Map.get(state,"edge_definitions"),[],fn({edge_id,edge_definition},acc) ->

      # 1. Get the edge dynamic node data
      node_data = Enum.reduce(Map.get(edge_definition,"inputs"),%{},fn({input_name,node_id},acc2) ->
        Map.put(acc2,node_id,Map.get(step_dynamic_node_cache,node_id))
      end)

      node_data = Enum.reduce(Map.get(edge_definition,"outputs"),node_data,fn({node_id,add_or_subtract},acc2) ->
        Map.put(acc2,node_id,Map.get(step_dynamic_node_cache,node_id))
      end)

      # 2. Spawn the solver
      #spawn(solver_name,current_subfunction_step,[stepper_id,edge_id,Map.get(stepper_edge,"lambda"),Map.get(stepper_edge,"inputs"),Map.get(stepper_edge,"targets"),step_size,current_timepoint,Map.get(state,"local_error_maximum")])

      spawn(solver_module_name,function_name,[solver_id,edge_id,edge_definition,node_data,Map.get(step_calculated_data,edge_id),step_size,timepoint,Map.get(newton_raphson_edge_definitions,edge_id)])

      [ edge_id | acc ]
    end)

    state = Map.put(state,"running_edges",running_edges)

    Map.put(state,"step_number_of_nr_iterations",Map.get(state,"step_number_of_nr_iterations") + 1)
  end

  def timestep_complete(state) do

   # IO.inspect("timestep_complete")

    state = reset_timestep_data(state)

    Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete()
    Map.put(state,"current_subfunction_step",List.first(Map.get(state,"solver_subfunction_sequence")))

  end

  def reset_timestep_data(state) do

    # Reset the node cache and calculated data
    state = Map.put(state,"step_dynamic_node_cache",%{})
    state = Map.put(state,"step_calculated_data",%{})
    state = Map.put(state,"step_number_of_nr_iterations",0)
    state = Map.put(state,"step_residuals_sum",0)
    Map.put(state,"step_converged_edges",[])

  end


end
