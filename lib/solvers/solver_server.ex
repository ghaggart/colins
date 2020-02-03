require Logger

defmodule Colins.Solvers.SolverServer do
    @moduledoc false

    use GenServer

    def start_link(solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum) do

        GenServer.start_link(__MODULE__,[solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum], [name: solver_id])
    end

    def init([solver_id,solver_type,partition_id,mesh_size,edge_definitions,local_error_maximum]) do

        {solver_module_name,_} = Code.eval_string("Colins.Solvers." <> solver_type)
        solver_subfunction_sequence = apply(solver_module_name,:get_solve_sequence,[])

        state = %{  "solver_id" => solver_id,
                    "solver_type" => solver_type,
                    "partition_id" => partition_id,
                    "solver_module_name" => solver_module_name,
                    "solver_subfunction_sequence" => solver_subfunction_sequence,
                    "edge_definitions"=>edge_definitions,
                    "current_subfunction_step"=> List.first(solver_subfunction_sequence),
                    "current_timestep_errors"=>%{},
                    "current_step_size"=>nil,
                    "current_timepoint"=>nil,
                    "running_edges"=>[],
                    "local_error_maximum"=>local_error_maximum,
                    "mesh_size"=>mesh_size}


        {:ok, state}

    end

    def run_edges(solver_id,timepoint,step_size) do

        GenServer.cast(solver_id,{:run_edges,timepoint,step_size})

    end

    def write_edges(solver_id) do

        GenServer.cast(solver_id,:write_edges)

    end

    def notify_edge_complete(solver_id,edge_id,optimal_step_size \\ nil) do

        GenServer.cast(solver_id,{:notify_edge_complete,edge_id,optimal_step_size})

    end

    def handle_cast({:run_edges,timepoint,step_size},state) do

        # 1. If no edge definitions, get them and store them.

        state = Map.put(state,"current_step_size",step_size)
        state = Map.put(state,"current_timepoint",timepoint)
        state = Map.put(state,"optimal_step_sizes",%{})

        # 2. Run the first subfunction step.

        {:noreply,run_subfunction_sequence(state)}

    end

    def handle_cast(:write_edges,state) do

        Enum.map(Map.get(state,"edge_definitions"),fn({edge_id,_}) ->

            Colins.Edges.EdgeData.write_to_file(edge_id)
        end)

        {:noreply,state}

    end

    def handle_cast({:notify_edge_complete,edge_id,optimal_step_size},state) do

        Logger.debug("\n " <> inspect(edge_id) <> " new optimal step_size: " <> inspect(optimal_step_size))

        running_edges = List.delete(Map.get(state,"running_edges"), edge_id)

        # 1. If there's an error/new step size, add it to the current_timestep_errors map
        state = case optimal_step_size do

            nil -> state

            _ -> optimal_step_sizes = Map.get(state,"optimal_step_sizes")
                 optimal_step_sizes = Map.put(optimal_step_sizes,edge_id,optimal_step_size)
                 Map.put(state,"optimal_step_sizes",optimal_step_sizes)

        end

        state = case {length(running_edges),Map.get(state,"current_subfunction_step")} do

            {a,_} when a > 0 -> Map.put(state,"running_edges",running_edges)

            {a,:complete} when a == 0 -> timestep_complete(state)

            _ -> run_subfunction_sequence(state)

        end

        {:noreply, state}

    end

    def run_subfunction_sequence(state) do

        current_subfunction_step = Map.get(state,"current_subfunction_step")

        solver_module_name = Map.get(state,"solver_module_name")
        timepoint = Map.get(state,"current_timepoint")
        step_size = Map.get(state,"current_step_size")
        solver_id = Map.get(state,"solver_id")
        local_error_maximum = Map.get(state,"local_error_maximum")
        mesh_size = Map.get(state,"mesh_size")

        # Spawn each edge process and populate the running_edges
        running_edges = Enum.reduce(Map.get(state,"edge_definitions"),[],fn({edge_id,edge_definition},acc) ->

            #spawn(solver_name,current_subfunction_step,[stepper_id,edge_id,Map.get(stepper_edge,"lambda"),Map.get(stepper_edge,"inputs"),Map.get(stepper_edge,"targets"),step_size,current_timepoint,Map.get(state,"local_error_maximum")])

            spawn(solver_module_name,current_subfunction_step,[solver_id,edge_id,edge_definition,step_size,timepoint,mesh_size,local_error_maximum])

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

    def timestep_complete(state) do

        optimal_step_sizes = Map.get(state,"optimal_step_sizes")

        Logger.debug("\nTimestep complete - new optimal_step_sizes: " <> inspect(optimal_step_sizes))

        state = case map_size(optimal_step_sizes) do

            0 -> Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete()
                 state
            _ -> smallest_step_size = Enum.min(optimal_step_sizes)
                  Logger.debug("\n Moving step size to smaller step size: " <> Float.to_string(smallest_step_size))
                  Colins.Nodes.Controller.reset_timestep_data()
                  Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_edges_complete_with_step_size_change(smallest_step_size)

        end

        Map.put(state,"current_subfunction_step",List.first(Map.get(state,"solver_subfunction_sequence")))

    end


end
