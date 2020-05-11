require Logger

defmodule Colins.Solvers.ExplicitSolverServer do
  @moduledoc false

  use GenServer

  def start_link(solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum) do

    GenServer.start_link(__MODULE__,[solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum], [name: solver_id])
  end

  def init([solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum,local_error_minimum]) do

    {solver_module_name,_} = Code.eval_string("Colins.Solvers." <> solver_type)
    solver_subfunction_sequence = apply(solver_module_name,:get_solve_sequence,[])

    # Get the unique dynamic node list for loading data at first subfunction step
    all_input_nodes = Enum.reduce(edge_definitions,[],fn({_edge_id,edge_definition},acc) ->
      Enum.concat(acc,Map.values(Map.get(edge_definition,"inputs")))
    end)
    all_output_nodes = Enum.reduce(edge_definitions,[],fn({_edge_id,edge_definition},acc) ->
#      IO.inspect(Map.get(edge_definition,"outputs"))
      Enum.concat(acc,Map.keys(Map.get(edge_definition,"outputs")))
    end)
    unique_dynamic_nodes = Enum.uniq(Enum.concat(all_input_nodes,all_output_nodes))
    #IO.inspect(unique_dynamic_nodes)

    state = %{  "solver_id" => solver_id,
                "solver_type" => solver_type,
                "partition_id" => partition_id,
                "solver_module_name" => solver_module_name,
                "solver_subfunction_sequence" => solver_subfunction_sequence,
                "edge_definitions"=>edge_definitions,
                 "unique_dynamic_nodes"=>unique_dynamic_nodes,
                "current_subfunction_step"=> List.first(solver_subfunction_sequence),
                "current_timestep_errors"=>%{},
                "current_step_size"=>nil,
                "current_timepoint"=>nil,
                "running_edges"=>%{},
                "step_dynamic_node_cache"=>%{},
                "step_calculated_data"=>%{},
                "local_error_maximum"=>local_error_maximum,
                "local_error_minimum"=>local_error_minimum,
                "step_min_optimal_step_size"=>nil,
                "step_max_error"=>0.0,
                "mesh_size"=>mesh_size}

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

  def parse_returned_error_and_step_size(state,returned_data) do

    #state = Map.put(state,"step_error_sum",Map.get(state,"step_error_sum") + Map.get(returned_data,"error_estimate"))

    # Set the step_max_error
    #   step_max_error = Map.get(state,"step_max_error")
    #   error_estimate = Map.get(returned_data,"error_estimate")
    #   step_max_error = case {error_estimate,step_max_error} do
    #     {a,b} when (a > b) -> error_estimate
    #     _ -> step_max_error
    #   end
    #   state = Map.put(state,"step_max_error",step_max_error)
    #
    #   # Set the step_min_optimal_step_size
    #   step_min_optimal_step_size = Map.get(state,"step_min_optimal_step_size")
    #   optimal_step_size = Map.get(returned_data,"optimal_step_size")
    #   step_min_optimal_step_size = case {optimal_step_size,step_min_optimal_step_size} do
    #     {a,b} when (a < b) -> optimal_step_size
    #     _ -> step_min_optimal_step_size
    #   end
    #   Map.put(state,"step_min_optimal_step_size",step_min_optimal_step_size)
    #

    # If the error estimate is larger than the current step_max_error, set this, and the step_min_optimal_step_size to the returned values.
    step_max_error = Map.get(state,"step_max_error")
    error_estimate = Map.get(returned_data,"error_estimate")
    state = case {error_estimate,step_max_error} do
      {a,b} when (a > b) -> state = Map.put(state,"step_max_error",error_estimate)
                            Map.put(state,"step_min_optimal_step_size", Map.get(returned_data,"optimal_step_size"))
      _ -> state
    end

  end

  def generate_step_dynamic_node_cache(state,timepoint,step_size) do

    step_dynamic_node_cache = Enum.reduce(Map.get(state,"unique_dynamic_nodes"),Map.get(state,"step_dynamic_node_cache"),fn(node_id,acc) ->

      node_data = case node_id do
        :timepoint -> timepoint
        _ -> Colins.Nodes.MasterNode.get_timepoint_data(node_id,timepoint)
      end
      Map.put(acc,node_id,node_data)
    end)
    step_dynamic_node_cache = Map.put(step_dynamic_node_cache,:timepoint,timepoint)
    state = Map.put(state,"step_dynamic_node_cache",step_dynamic_node_cache)

  end

  def run_subfunction_sequence(state) do

    # 1. Get the step_dynamic_node_cache and set if not yet loaded
    # 2. Spawn the subfunction step with MFA and step_calculated_data (subfunction values ie k1)

    Logger.debug(inspect(state))

    timepoint = Map.get(state,"current_timepoint")
    step_size = Map.get(state,"current_step_size")

    state = case map_size(Map.get(state,"step_dynamic_node_cache")) do
      0 -> generate_step_dynamic_node_cache(state,timepoint,step_size)
      _ -> state
    end

    step_dynamic_node_cache = Map.get(state,"step_dynamic_node_cache")

    current_subfunction_step = Map.get(state,"current_subfunction_step")

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

     # IO.inspect(step_dynamic_node_cache)

      # 2. Spawn the solver
      #spawn(solver_name,current_subfunction_step,[stepper_id,edge_id,Map.get(stepper_edge,"lambda"),Map.get(stepper_edge,"inputs"),Map.get(stepper_edge,"targets"),step_size,current_timepoint,Map.get(state,"local_error_maximum")])

      spawn(solver_module_name,current_subfunction_step,[solver_id,edge_id,edge_definition,node_data,Map.get(step_calculated_data,edge_id),step_size,timepoint,mesh_size,local_error_maximum])

      [ edge_id | acc ]
    end)

    state = Map.put(state,"running_edges",running_edges)

    # Set the next subfunction
    solver_subfunction_sequence = Map.get(state,"solver_subfunction_sequence")
    subfunction_sequence_index = Enum.find_index(solver_subfunction_sequence, fn(x) -> (x == current_subfunction_step) end)

    case {Map.get(state,"current_subfunction_step"),Enum.at(solver_subfunction_sequence, -1)} do

      {a,b} when a == b -> Map.put(state,"current_subfunction_step",:complete)
      _ -> Map.put(state,"current_subfunction_step",Enum.at(solver_subfunction_sequence,(subfunction_sequence_index + 1)))

    end

  end

  def reset_timestep_data(state) do

    state = Map.put(state,"step_dynamic_node_cache",%{})
    state = Map.put(state,"step_calculated_data",%{})
    state = Map.put(state,"step_max_error",0.0)
    state = Map.put(state,"step_min_optimal_step_size",Map.get(state,"current_step_size"))

    Map.put(state,"current_subfunction_step",List.first(Map.get(state,"solver_subfunction_sequence")))

  end

  def check_errors(state) do

    # IO.inspect("check_residuals")

    # This function checks whether the total error value

    # If its greater than a certain threshold
    #     reduce the step size to the optimal value
    #     If the new step size is smaller than the smallest step size, move to implicit solver server.
    # If its smaller than the error_minimum, reset the step size (increase it).
    #
    # If it is zero, or within the error tolerance,
    #     set the current_subfunction_step to :complete, send the previous_estimate to the nodes, and complete the timestep.

    step_max_error = Map.get(state,"step_max_error")
    #local_error_maximum = 1.0e-12
    local_error_maximum = Map.get(state,"local_error_maximum")
    local_error_minimum = Map.get(state,"local_error_minimum")

    #IO.inspect("here")
    #IO.inspect(state)

    #tolerance of RKF method εj = 10−12, j = 1,...,N;
    #IO.inspect("check_errors")
    #IO.inspect(step_max_error)
    #IO.inspect(abs(step_max_error))
    #IO.inspect(local_error_maximum)

    case {abs(step_max_error),local_error_minimum,local_error_maximum} do

      #If step residuals sum is zero, or within the error tolerance,
      #   set the current_subfunction_step to :complete, send the previous_estimate to the nodes, and complete the timestep.
      {a,b,c} when (a > b and a < c) -> Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete()

      _ -> Colins.Nodes.Controller.reset_timestep_data()
           Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete_with_step_size_change(Map.get(state,"step_min_optimal_step_size"),Map.get(state,"partition_id"))
    end

    state = reset_timestep_data(state)

    #IO.inspect(state)
    #System.halt(0)
  end


  def handle_cast({:run_edges,timepoint,step_size},state) do

    # 1. If no edge definitions, get them and store them.

    #IO.inspect("timepoint to run")
    #IO.inspect(timepoint)

    state = Map.put(state,"current_step_size",step_size)
    state = Map.put(state,"current_timepoint",timepoint)
    state = Map.put(state,"step_min_optimal_step_size",step_size)


    # 2. Run the subfunction sequence

    {:noreply,run_subfunction_sequence(state)}

  end

  def handle_cast(:write_edges,state) do

    Enum.map(Map.get(state,"edge_definitions"),fn({edge_id,_}) ->

      Colins.Edges.EdgeData.write_to_file(edge_id)
    end)

    {:noreply,state}

  end


  # When an edge completes, take the returned_data and add it to the step_calculated_data map.
  # step_calculated_data = {edge_id => {"k1" => 0.121, "k2" => 0.322} }
  def handle_cast({:notify_edge_complete,edge_id,returned_data,subfunction_type},state) do

    #Logger.debug("\n " <> inspect(edge_id) <> " new optimal step_size: " <> inspect(optimal_step_size))

    # 1. Remove this edge from the running_edges
    running_edges = List.delete(Map.get(state,"running_edges"), edge_id)

    # 2. Add the returned_data to the step_calculated_data map.
    step_calculated_data = Map.get(state,"step_calculated_data")

    edge_step_calculated_data = case Map.has_key?(step_calculated_data,edge_id) do

        true -> Map.get(step_calculated_data,edge_id)
        false -> %{}

    end

    # Parse the specific data
    state = case subfunction_type do
      # Add the error sum for this step.
      :calculate_weighted_average_and_error -> parse_returned_error_and_step_size(state,returned_data)
      nil -> state
    end

    #edge_step_calculated_data = Map.get(step_calculated_data,edge_id)
    edge_step_calculated_data = Enum.reduce(returned_data,edge_step_calculated_data,fn({key,value},acc) ->
      Map.put(acc,key,value)
    end)
    #step_calculated_data = Map.put(step_calculated_data,edge_id,edge_step_calculated_data)
    state = Map.put(state,"step_calculated_data",Map.put(step_calculated_data,edge_id,edge_step_calculated_data))


    # 4. If more running edges, do nothing.
    #    If no more subfunction steps, complete timestep
    #    Else run the next subfunction step
    state = case {length(running_edges),Map.get(state,"current_subfunction_step")} do

      {a,_} when a > 0 -> Map.put(state,"running_edges",running_edges)

      {a,:complete} when a == 0 -> check_errors(state)

      _ -> run_subfunction_sequence(state)

    end

    {:noreply, state}

  end


end
