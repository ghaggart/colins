require Logger
use Timex

defmodule Colins.Timesteps.TimestepController do
    @moduledoc "Timestep controller for multi-rate solvers"

    use GenServer

    def start_link() do

        GenServer.start_link(__MODULE__, [],  [name: __MODULE__])

    end

    def init([]) do

        {:ok, %{}}

    end

    def setup_simulation(sim_id,results_folder,step_size_edge_map,max_timepoint,mesh_size) do

        GenServer.cast(__MODULE__,{:setup_simulation,sim_id,results_folder,step_size_edge_map,max_timepoint,mesh_size})

    end

    def start_simulation() do

        GenServer.cast(__MODULE__,:start_simulation)

    end

    def notify_edges_complete(errors \\ %{}) do

        GenServer.cast(__MODULE__,{:notify_edges_complete,errors})

    end

    def notify_node_commit_complete() do

        GenServer.cast(__MODULE__,:notify_node_commit_complete)

    end

    def notify_node_interpolation_complete() do

        GenServer.cast(__MODULE__,:notify_node_interpolation_complete)

    end

    def handle_cast({:setup_simulation,sim_id,results_folder,step_size_edge_map,max_timepoint,mesh_size},state) do

        state = Map.put(state,"mesh_size",mesh_size)
        state = Map.put(state,"sim_id",sim_id)
        state = Map.put(state,"results_folder",results_folder)

        state = Map.put(state,"max_timepoint",max_timepoint/1)

        state = Map.put(state,"step_size_edge_map",step_size_edge_map)

        state = Map.put(state,"completed_timepoints",%{})

        state = Map.put(state,"current_timepoint",0.0)

        state = Map.put(state,"smallest_step_size",List.first(Enum.sort(Map.keys(step_size_edge_map))))
        state = Map.put(state,"current_step_size",List.last(Enum.sort(Map.keys(step_size_edge_map))))

        state = Map.put(state,"update_current_timepoint",:false)

        state = Map.put(state,"sim_complete",:false)

        state = Map.put(state,"last_completed_timepoints",%{})

        {:noreply,state}

    end

    def handle_cast(:start_simulation,state) do

        state = Map.put(state,"simulation_start_time",Timex.now())

        {:noreply,run_next_step(state)}

    end

    def handle_cast({:notify_edges_complete,errors},state) do

#        errors = %{}

        state = case length(Map.keys(errors)) do

            0 -> Colins.Nodes.Controller.commit_timepoint_queue()
                 state

            _ -> step_size_changes(state,errors)

        end

        {:noreply,state}

    end

    def handle_cast(:notify_node_commit_complete,state) do

        # Interpolate here. Interpolate from the current_timepoint to the "next_timepoint", onto the mesh.

        current_timepoint = Map.get(state,"current_timepoint")
        current_step_size = Map.get(state,"current_step_size")
        mesh_size = Map.get(state,"mesh_size")
        next_timepoint = Float.round(current_timepoint + current_step_size,11)

        Colins.Nodes.Controller.interpolate_all_nodes(Map.get(state,"mesh_size"),current_timepoint,next_timepoint)

        # If the update_current_timepoint flag is set, update the current_timepoint with the next_timepoint
        state = case Map.get(state,"update_current_timepoint") do

            :true -> Map.put(state,"current_timepoint",next_timepoint)
            :false -> state

        end

        # Reset the update_current_timepoint flag to false
        state = Map.put(state,"update_current_timepoint",:false)

        # Add this timepoint to the completed_timepoint
        state = case {Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size")} do

           {x,y} when x != y -> update_last_completed_map(state,next_timepoint)
           _ -> state

        end

        # If the current_step_size is not the smallest_step_size, and there is more than 1 step_size, get the next largest step size
        state = case {Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size"),length(Map.keys(Map.get(state,"step_size_edge_map")))} do

            {a,b,_} when a == b -> state
            {_,_,c} when c == 1 -> state
            _ -> set_next_largest_step_size(state)

        end

        # Wait for the interpolation to finish.
        {:noreply,state}

    end

    def handle_cast(:notify_node_interpolation_complete,state) do

        {:noreply,run_next_step(state)}

    end

    @doc "Run this for the smallest step size.
          Checks the previously completed step size map for timepoints that have completed.
          If the next timepoint is bigger than any of these, get the largest step size for this timepoint and run that instead."
    def check_which_step_size_to_run(state) do

        next_timepoint = Map.get(state,"current_step_size") + Map.get(state,"current_timepoint")

        last_completed_timepoints = Map.get(state,"last_completed_timepoints")

        lowest_completed_timepoint = List.first(Enum.sort(Map.keys(last_completed_timepoints)))

        case {next_timepoint,lowest_completed_timepoint} do

            # If the next timepoint is bigger than or equal to a previous completed one, run the next one for that instead.
            # There could be multiple step sizes for this timepoint, so get the largest from the list.
            {a,b} when a >= b -> state = Map.put(state,"current_step_size",List.last(Enum.sort(Map.get(last_completed_timepoints,lowest_completed_timepoint))))
                                 Map.put(state,"update_current_timepoint",:false)

            # This is the smallest step size, and the next timepoint is not bigger than the previously completed other step size timepoints
            _ -> Map.put(state,"update_current_timepoint",:true)

        end

    end

    @doc "Runs the next step"
    def run_next_step(state) do

        # If the current_step_size is the smallest_step_size, check if we should run this step size, or a bigger one.
        state = case {Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size")} do

            {x,y} when x == y -> check_which_step_size_to_run(state)
            _ -> state

        end

        next_timepoint = Float.round(Map.get(state,"current_timepoint") + Map.get(state,"current_step_size"),11)

        case {next_timepoint,Map.get(state,"max_timepoint"),Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size")} do

            # If this is the smallest step size, and the next timepoint is bigger than the max_timepoint, finish the simulation
            {w,x,y,z} when (w > x and y == z) -> finish_simulation(state)

            # Else, run the new timepoint
            _ -> run_new_timepoint(state,next_timepoint)

        end

    end

    def run_new_timepoint(state,next_timepoint) do

        current_step_size = Map.get(state,"current_step_size")

        #If this is is a dev env set the interval length
        #case Application.get_env(:logger,:level) do
        #    :dev -> Colins.Timesteps.TimestepData.set_variable(next_timepoint,"timestamp_timepoint_started_stepsize_"<> Float.to_string(current_step_size),:os.system_time(:millisecond))
        #    _ ->
        #end
        Colins.Timesteps.TimestepData.set_variable(next_timepoint,"timestamp_timepoint_started_stepsize_"<> Float.to_string(current_step_size),:os.system_time(:millisecond))

        Logger.debug("\nRunning timepoint: - " <> Float.to_string(next_timepoint))

        Logger.debug("\nState: " <> inspect(state))

        current_step_size = Map.get(state,"current_step_size")

        Logger.debug("\nstep size: " <> inspect(current_step_size))

        solvers_and_edges_for_this_step_size = Map.get(Map.get(state,"step_size_edge_map"),current_step_size)

        Logger.debug("\nsolvers_and_edges_for_this_step_size: " <> inspect(solvers_and_edges_for_this_step_size))

        Enum.map(solvers_and_edges_for_this_step_size,fn({solver_id,edge_list}) ->

            Logger.debug("\nSolver: " <> inspect(solver_id))
            Logger.debug("\nEdge_list: " <> inspect(edge_list))

            Colins.Solvers.SolverServer.run_edges(solver_id,edge_list,next_timepoint,Map.get(state,"current_step_size"))

        end)

        # TODO: Do we need to update the state with something running?

        state

    end

    @doc "Update the last completed map, delete the old one and add the new one"
    def update_last_completed_map(state,next_timepoint) do

        current_step_size = Map.get(state,"current_step_size")

        last_completed_timepoints = Map.get(state,"last_completed_timepoints")


        # Remove the previous entry

        last_timepoint = next_timepoint - current_step_size

        step_size_list = case Map.fetch(last_completed_timepoints,last_timepoint) do

            {:ok, step_size_list } -> step_size_list
            :error -> []

        end

        step_size_list = Enum.reject(step_size_list, fn x -> x == last_timepoint end)

        last_completed_timepoints = Map.put(last_completed_timepoints,last_timepoint,step_size_list)


        # Add the new entry

        step_size_list = case Map.fetch(last_completed_timepoints,next_timepoint) do

            {:ok, step_size_list } -> step_size_list
            :error -> []

        end

        step_size_list = [ current_step_size | step_size_list ]

        last_completed_timepoints = Map.put(last_completed_timepoints,next_timepoint,step_size_list)

        Map.put(state,"\nlast_completed_timepoints",last_completed_timepoints)

        Logger.debug("\nlast completed timepoints: " <> last_completed_timepoints)

        last_completed_timepoints

    end

    @doc "There are timestep changes occuring - an edge is moving timestep"
    def step_size_changes(state,errors) do

        #IO.inspect("we are here")

         # errors = %{ edge_id => new_step_size}

         # step_size_edge_map = %{ step_size => %{ solver_type => [ edge_id, edge_id ] } }


         # Flush the node timepoint queues - should happen in node_controller
         # Update the state vars


         # 1. Get the current_step_size.

         current_step_size = Map.get(state,"current_step_size")


         # Set the update_current_timepoint flag to false
         state = Map.put(state,"update_current_timepoint",false)


         # TODO: Enable this to use multiple methods
         #solvers_and_edges = Map.get(state,"step_size_edge_map")

         # 2. Remove the edges that match

         all_step_size_edge_map = Map.get(state,"step_size_edge_map")
         current_step_size_edge_map = Map.get(all_step_size_edge_map,current_step_size)
         edge_list = Map.get(current_step_size_edge_map,"AdaptiveRungeKutta4")

         edges_to_move = Map.keys(errors)

        # IO.inspect(edges_to_move)
        # IO.inspect(edge_list)

         new_edge_list = Enum.reject(edge_list,fn(x) -> Enum.member?(edges_to_move,x) end)

         current_step_size_edge_map = Map.put(current_step_size_edge_map,"AdaptiveRungeKutta4",new_edge_list)

        # all_step_size_edge_map = Map.put(all_step_size_edge_map,current_step_size,current_step_size_edge_map)

         #step_size_edge_map = Map.put(step_size_edge_map,current_step_size,Map.put(,"AdaptiveRungeKutta4",new_edge_list))


         # 3. Add new step_sizes

         all_step_size_edge_map = Enum.reduce(errors,all_step_size_edge_map,fn({edge_id,step_size},acc) ->

            case Map.has_key?(acc,step_size) do

                false -> solver_map = %{"AdaptiveRungeKutta4" => [edge_id]}
                         Map.put(acc,step_size,solver_map)

                true -> solver_map = Map.get(acc,step_size)
                        edge_list = [ edge_id | Map.get(solver_map,"AdaptiveRungeKutta4")]
                        solver_map = edge_list
                        Map.put(acc,step_size,solver_map)

            end

         end)

         state = Map.put(state,"step_size_edge_map",all_step_size_edge_map)

       #  IO.inspect(state)

         # 4. Check if the edge_list is the same length as the new_edge_list.
         # If so, delete the entry for the current_step_size
         # Get the next largest step size to run.
         # Otherwise, just rerun the same step

          state = case length(new_edge_list) do

               a when a == 0 -> state = Map.put(state,"step_size_edge_map",Map.delete(all_step_size_edge_map,current_step_size))
                                set_next_largest_step_size(state)
               _ -> state

          end

          # Rerun the step

          run_next_step(state)

    end

    @doc "This only runs when the current_step_size is not the smallest_step_size and there is more than 1 step_size"
    def set_next_largest_step_size(state) do

        current_step_size = Map.get(state,"current_step_size")

        Logger.debug("\nset_next_largest_step_size: " <> inspect(current_step_size))

        # Get a list of step_sizes, ordered small to big
        step_size_list = Enum.sort(Map.keys(Map.get(state,"step_size_edge_map")))

        Logger.debug("\nstep_size_list: " <> inspect(step_size_list))

        # Find the list index of the current_step_size
        #current_step_size_index = Enum.find_index(step_size_list,fn(x) -> x == current_step_size end)
        current_step_size_index = Enum.find_index(step_size_list,fn(x) -> match?(x,current_step_size) end)

        Logger.debug("\ncurrent_step_size_index: " <> inspect(current_step_size_index))

      #  IO.inspect(current_step_size_index + 1)
      #  IO.inspect(length(step_size_list))

      #  non_nil_current_step_size_index = case current_step_size_index do

      #      nil -> 0
      #      _ -> current_step_size_index

      #  end

        # Get the next largest step size
        # If this is the last element, just set the same step_size
        case {(current_step_size_index + 1),length(step_size_list)} do

            # This means that if the step size has changed, but the old removed, it will do this one instead.
            {a,b} when a == b -> Map.put(state,"current_step_size",Enum.fetch!(step_size_list,current_step_size_index))

            _ -> #next_step_size = Enum.fetch!(step_size_list,(current_step_size_index + 1))
                 Map.put(state,"current_step_size",Enum.fetch!(step_size_list,(current_step_size_index + 1)))

        end

    end

    def write_out_benchmark_data(state) do

        Colins.Timesteps.TimestepData.write_to_file()

        file_path = Path.join([Map.get(state,"results_folder"),Map.get(state,"sim_id"),"benchmark_data"])

        file = File.open!(file_path, [:write])

        # Simulation execution length in microseconds
        string = "simulation_execution_length_microseconds," <> Integer.to_string(Map.get(state,"simulation_execution_length_microseconds")) <> "\n"

        # Number of schedulers/cores
        string = string <> "system_schedulers_integer," <> Integer.to_string(System.schedulers) <> "\n"
        string = string <> "system_schedulers_online_integer," <> Integer.to_string(System.schedulers_online) <> "\n"

        # Total memory
        mem = :erlang.memory
        string = string <> "memory_total_bytes," <> Integer.to_string(mem[:total]) <> "\n"
        string = string <> "memory_processes_bytes," <> Integer.to_string(mem[:processes]) <> "\n"
        string = string <> "memory_processes_used_bytes," <> Integer.to_string(mem[:processes_used]) <> "\n"
        string = string <> "memory_system_bytes," <> Integer.to_string(mem[:system]) <> "\n"
        string = string <> "memory_atom_bytes," <> Integer.to_string(mem[:atom]) <> "\n"
        string = string <> "memory_atom_used_bytes," <> Integer.to_string(mem[:atom_used]) <> "\n"
        string = string <> "memory_binary_bytes," <> Integer.to_string(mem[:binary]) <> "\n"
        string = string <> "memory_code_bytes," <> Integer.to_string(mem[:code]) <> "\n"
        string = string <> "memory_code_bytes," <> Integer.to_string(mem[:ets]) <> "\n"

        # Build info
        string = string <> "system_build_string," <> Map.get(System.build_info,:build) <> "\n"

        IO.write(file,string)
        File.close(file)

    end

    def finish_simulation(state) do

        # Write out benchmark data
        state = Map.put(state,"simulation_end_time",Timex.now())
        state = Map.put(state,"simulation_execution_length_microseconds",Timex.diff(Map.get(state,"simulation_end_time"),Map.get(state,"simulation_start_time")))

        Logger.info("\nsimulation finished")

        IO.inspect("simulation finished")

        IO.inspect(state)

        write_out_benchmark_data(state)

       # edge_list = Enum.reduce(Map.get(state,"step_size_edge_map"),[],fn({step_size,solver_map},acc1) ->

        #    solver_edge_list = Enum.reduce(solver_map,[],fn({solver_id,sub_edge_list},acc2) ->

        #        Enum.concat(acc2,sub_edge_list)
        #    end)

        #    Enum.concat(acc1,solver_edge_list)
       # end)

      #  Enum.map
        #Colins.Edges.EdgeData.write_results_to_file()

        # Tell all the edges to write to file.
        Enum.map(Map.get(state,"step_size_edge_map"),fn({step_size,solver_map}) ->

            Enum.map(solver_map,fn({solver_id,sub_edge_list}) ->

                Enum.map(sub_edge_list,fn(edge_id) ->
                    Colins.Edges.EdgeData.write_to_file(edge_id)
                end)
            end)
        end)

        Colins.Nodes.Controller.write_results_to_file()

        state

    end

end