require Logger
use Timex

defmodule Colins.Timesteps.SingleFixedTimestepController do
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

  def handle_cast({:setup_simulation,sim_id,results_folder,step_size_edge_map,max_timepoint,mesh_size},state) do

    state = Map.put(state,"mesh_size",mesh_size)
    state = Map.put(state,"sim_id",sim_id)
    state = Map.put(state,"results_folder",results_folder)

    state = Map.put(state,"max_timepoint",max_timepoint/1)

    state = Map.put(state,"step_size_edge_map",step_size_edge_map)

    state = Map.put(state,"completed_timepoints",%{})

    state = Map.put(state,"current_timepoint",0.0)

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

    Colins.Nodes.Controller.commit_timepoint_queue()


    {:noreply,state}

  end

  def handle_cast(:notify_node_commit_complete,state) do

    # Interpolate here. Interpolate from the current_timepoint to the "next_timepoint", onto the mesh.

    current_timepoint = Map.get(state,"current_timepoint")
    current_step_size = Map.get(state,"current_step_size")
    mesh_size = Map.get(state,"mesh_size")
    next_timepoint = Float.round(current_timepoint + current_step_size,11)

   # Colins.Nodes.Controller.interpolate_all_nodes(Map.get(state,"mesh_size"),current_timepoint,next_timepoint)

    # If the update_current_timepoint flag is set, update the current_timepoint with the next_timepoint
    state = case Map.get(state,"update_current_timepoint") do

      :true -> Map.put(state,"current_timepoint",next_timepoint)
      :false -> state

    end

    # Wait for the interpolation to finish.
    {:noreply, run_next_step(state)}

  end


  @doc "Runs the next step"
  def run_next_step(state) do

    next_timepoint = Float.round(Map.get(state,"current_timepoint") + Map.get(state,"current_step_size"),11)

    case {next_timepoint,Map.get(state,"max_timepoint")} do

      # If this is the smallest step size, and the next timepoint is bigger than the max_timepoint, finish the simulation
      {w,x} when (w > x) -> finish_simulation(state)

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

      #Colins.Solvers.SolverServer.run_edges(solver_id,edge_list,next_timepoint,Map.get(state,"current_step_size"))
      Colins.Solvers.ExplicitSolverServer.run_edges(solver_id,edge_list,next_timepoint,Map.get(state,"current_step_size"))

    end)

    Map.put(state,"current_timepoint",next_timepoint)

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