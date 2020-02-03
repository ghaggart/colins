require Logger
use Timex

defmodule Colins.Timesteps.AdaptiveMultiRateTimestepController do
  @moduledoc "Timestep controller for adaptive multi-rate solvers"

  use GenServer

  def start_link() do

    GenServer.start_link(__MODULE__, [],  [name: __MODULE__])

  end

  def init([]) do

    {:ok, %{}}

  end

  def set_simulation_initialisation_time_microseconds(simulation_initialisation_time_microseconds) do

    GenServer.cast(__MODULE__,{:set_simulation_initialisation_time_microseconds,simulation_initialisation_time_microseconds})

  end

  def setup_simulation(sim_id,results_folder,partitions,max_timepoint,mesh_size) do

    GenServer.cast(__MODULE__,{:setup_simulation,sim_id,results_folder,partitions,max_timepoint,mesh_size})

  end

  def start_simulation() do

    GenServer.cast(__MODULE__,:start_simulation)

  end

  def notify_edges_complete() do

    GenServer.cast(__MODULE__,{:notify_edges_complete})

  end

  def notify_edges_complete_with_step_size_change(new_step_size,partition_id) do

    GenServer.cast(__MODULE__,{:notify_edges_complete_with_step_size_change,new_step_size,partition_id})

  end

  def notify_node_commit_complete() do

    GenServer.cast(__MODULE__,:notify_node_commit_complete)

  end

  def notify_node_interpolation_complete() do

    GenServer.cast(__MODULE__,:notify_node_interpolation_complete)

  end

  def calculate_step_size_decimal_places(mesh_size,explicit_implicit_switch_step_size_tolerance) do

    case {mesh_size,explicit_implicit_switch_step_size_tolerance} do

      {a,b} when (a <= b) -> Colins.Utilities.Math.number_of_decimal_places(mesh_size)
      _ -> Colins.Utilities.Math.number_of_decimal_places(explicit_implicit_switch_step_size_tolerance)

    end

  end


  @doc " Build a map of step sizes and partitions:
        %{ step_size => [ partition_ids ] }"
  def build_step_size_map(partitions) do

    # Build a map of step sizes and partitions:
    # %{ step_size => [ partition_ids ] }
    Enum.reduce(partitions,%{},fn({partition_id,solver_data},acc) ->

      step_size = Map.get(solver_data,"start_step_size")

      case Map.has_key?(acc,step_size) do

        true -> partition_list = Map.get(acc,step_size)
                Map.put(acc,step_size,[ partition_id | partition_list ])
        false -> Map.put(acc,step_size,[ partition_id ])

      end

    end)

  end

  def move_partition_to_implicit_solver(state,new_step_size,partition_id) do

   # IO.inspect("move_partition_to_implicit_solver")
   # IO.inspect(new_step_size)

    partitions = Map.get(state,"partitions")

    partition = Map.get(partitions,partition_id)

    current_running_solver_type = Map.get(partition,"solver_type_running")

    partition = Map.put(partition,"solver_type_running","implicit")

    partitions = Map.put(partitions,partition_id,partition)

    state = Map.put(state,"partitions",partitions)

    implicit_step_size = case new_step_size do

      a when a < 1.0e-12 -> 1.0e-9

      a when a >= 1.0e-12 and a < 1.0e-9 -> 1.0e-6

      a when a >= 1.0e-9 and a < 1.0e-6 -> 0.001

      a when a >= 1.0e-6 and a < 1.0e-3 -> 0.01

      a when a >= 1.0e-3 and a < 1.0e-1 -> 0.1

    end

    # switch the partition solver type running to the implicit
   # state = Map.put(state,"partitions",Map.put(Map.get(state,"partitions",partition_id),"solver_type_running","implicit"))

    #IO.inspect(state)

    # Update the step sizes and then run the new timepoint
    # Step size set to 0.1 as per the LASSIE config, unless that is already running, in which case use the specified one

    case current_running_solver_type do
       "explicit" -> run_new_timepoint(update_step_sizes(state,implicit_step_size,partition_id),Map.get(state,"current_timepoint"))
       "implicit" -> run_new_timepoint(update_step_sizes(state,new_step_size,partition_id),Map.get(state,"current_timepoint"))
    end


  end

  def update_step_sizes_and_rerun_step(state,new_step_size,partition_id) do

    #IO.inspect("update_step_sizes_and_rerun_step")
    #IO.inspect(new_step_size)

    new_step_size = Float.floor(new_step_size,Map.get(state,"step_size_decimal_places"))

    state = run_new_timepoint(update_step_sizes(state,new_step_size,partition_id),Map.get(state,"current_timepoint"))

  end

  def update_step_sizes(state,new_step_size,partition_id) do

 #   IO.inspect("update_step_sizes")
 #   IO.inspect(new_step_size)
 #   IO.inspect(partition_id)

 #   IO.inspect(state)

    # move the partition from the step size map
    step_size_map = Map.get(state,"step_size_map")
    current_step_size = Map.get(state,"current_step_size")

    new_step_size_map = Enum.reduce(step_size_map,%{},fn({step_size,partition_list},acc) ->

      case {current_step_size,step_size,length(partition_list)} do

        # 1 partition for current step size, do not put the step size in the new partition_map
        {a,b,c} when (a == b and c == 1) -> acc

        # >1 partitions for current step size, remove this from the partition list and return in new partition map
        {a,b,c} when (a == b and c > 1) -> Map.put(acc,step_size,List.delete(partition_list,partition_id))

        # 3. not this current step size, don't edit (add to the acc)
        {a,b,_} when (a != b) -> Map.put(acc,step_size,partition_list)

      end

    end)

    new_step_size_map = case Map.has_key?(new_step_size_map,new_step_size) do

      true ->  partition_list = Map.get(new_step_size_map,new_step_size)
               Map.put(new_step_size_map,new_step_size,[ partition_id | partition_list ])
      false -> Map.put(new_step_size_map,new_step_size,[ partition_id ])

    end

    state = Map.put(state,"step_size_map",new_step_size_map)

    state = Map.put(state,"running_partitions",List.delete(Map.get(state,"running_partitions"),partition_id))

    # if this is smaller than the smallest step size, update smallest_step_size

    # set the smallest_step_size

    smallest_step_size = Enum.min(Map.keys(new_step_size_map))

    state = Map.put(state,"smallest_step_size",smallest_step_size)

    # update the current step size with this one if its smaller - TODO: Is this correct? for multi-rate solvers probably not!
    # Probably want to set this during the calculation of the next step size
     Map.put(state,"current_step_size",smallest_step_size)

  end

  def multi_rate_interpolate(state) do

    current_timepoint = Map.get(state,"current_timepoint")
    current_step_size = Map.get(state,"current_step_size")
    next_timepoint = Float.round(current_timepoint + current_step_size,11)

    smallest_step_size = Map.get(state,"smallest_step_size")

    # If the current step size is bigger than the smallest step size - interpolate!
    #
    running_interpolation = case {current_step_size,smallest_step_size} do

      {x,y} when (x > y) -> Colins.Nodes.Controller.interpolate_all_nodes(Map.get(state,"mesh_size"),current_timepoint,next_timepoint)
                            :true
      _ -> :false

    end

    # If the update_current_timepoint flag is set, update the current_timepoint with the next_timepoint
    state = case Map.get(state,"update_current_timepoint") do

      :true -> Map.put(state,"current_timepoint",next_timepoint)
      :false -> state

    end

    # Reset the update_current_timepoint flag to false
    state = Map.put(state,"update_current_timepoint",:false)

    # Add this timepoint to the completed_timepoint
    state = case {Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size")} do

      {x,y} when x != y -> update_last_completed_timepoints(state,Map.get(state,"running_partitions"),next_timepoint)
      _ -> state

    end

    # If the current_step_size is not the smallest_step_size, and there is more than 1 step_size, get the next largest step size
    case running_interpolation do

      :true -> set_next_largest_step_size(state)
      :false -> run_next_step(state)

    end

  end

  def run_next_step_single_rate(state) do

    next_timepoint = Float.round(Map.get(state,"current_timepoint") + Map.get(state,"current_step_size"),11)

    case {next_timepoint,Map.get(state,"max_timepoint")} do

      # If this is the smallest step size, and the next timepoint is bigger than the max_timepoint, finish the simulation
      {w,x} when (w >= x) -> finish_simulation(state)

      # Else, run the new timepoint
      _ -> run_new_timepoint(state,next_timepoint)

    end

  end

  def run_next_step_multi_rate(state) do

    # If the current_step_size is the smallest_step_size, check if we should run this step size, or a bigger one.
    # If theres only 1 step size, don't check.
    state = case {Map.get(state,"current_step_size"),Map.get(state,"smallest_step_size"),map_size(Map.get(state,"step_size_map"))} do

      {x,y,z} when (x == y and z > 1) -> check_which_step_size_to_run(state)
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


  @doc "Runs the next step"
  def run_next_step(state) do

    # If there is more than 1 partition (ie more than 1 rate - run this as a multi-rate version)

    case Map.get(state,"number_of_partitions") do

      x when x == 1 -> run_next_step_single_rate(state)
      _ -> run_next_step_multi_rate(state)

    end

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

  def run_new_timepoint(state,next_timepoint) do

    current_step_size = Map.get(state,"current_step_size")
    max_timepoint = Map.get(state,"max_timepoint")

    number_of_timesteps_remaining = round((max_timepoint - next_timepoint) / current_step_size)

    case Colins.Utilities.Modulo.remainder_zero?(number_of_timesteps_remaining,100) do
        true -> IO.inspect("Running timepoint: " <> Float.to_string(next_timepoint) <> " out of " <> Float.to_string(max_timepoint))
        _ -> nil
    end

    #IO.inspect("run_new_timepoint")
    #IO.inspect(next_timepoint)

    #IO.inspect(current_step_size)
    #IO.inspect(state)

    #If this is is a dev env set the interval length
    #case Application.get_env(:logger,:level) do
    #    :dev -> Colins.Timesteps.TimestepData.set_variable(next_timepoint,"timestamp_timepoint_started_stepsize_"<> Float.to_string(current_step_size),:os.system_time(:millisecond))
    #    _ ->
    #end
    Colins.Timesteps.TimestepData.set_variable(next_timepoint,"interval_started",:os.system_time(:millisecond))

    Logger.debug("\nRunning timepoint: - " <> Float.to_string(next_timepoint))

    Logger.debug("\nState: " <> inspect(state))

    Logger.debug("\nstep size: " <> inspect(current_step_size))

    partitions_for_this_step_size = Map.get(Map.get(state,"step_size_map"),current_step_size)

    partitions = Map.get(state,"partitions")

    Logger.debug("\npartitions_for_this_step_size: " <> inspect(partitions_for_this_step_size))

    running_partitions = Enum.reduce(partitions_for_this_step_size,[],fn(partition_id,acc) ->

      partition = Map.get(partitions,partition_id)

      Logger.debug("\nPartition solver running: " <> inspect(partition))

      run_edges(Map.get(partition,"solver_type"),partition,next_timepoint,current_step_size)

      [ partition_id | acc ]

    end)

    state = Map.put(state,"running_partitions",running_partitions)

    Map.put(state,"current_timepoint",next_timepoint)

  end

  # If its ODE type, check which solver_type_running - explicit or implicit
  def run_edges("ODE",partition,next_timepoint,current_step_size) do

      case Map.get(partition,"solver_type_running") do
          "explicit" -> Colins.Solvers.ExplicitSolverServer.run_edges(Map.get(partition,"explicit_solver_id"),next_timepoint,current_step_size)
          "implicit" -> Colins.Solvers.ImplicitSolverServer.run_edges(Map.get(partition,"implicit_solver_id"),next_timepoint,current_step_size)
          _ -> nil
      end

  end

  # If its a normal type, check whether its a member of the explicit or implicit solvers.
  def run_edges(solver_type,partition,next_timepoint,current_step_size) do

    case Enum.member?(Colins.Solvers.Utils.get_explicit_solver_list(),solver_type) do
      true -> Colins.Solvers.ExplicitSolverServer.run_edges(Map.get(partition,"solver_id"),next_timepoint,current_step_size)
    end

    case Enum.member?(Colins.Solvers.Utils.get_explicit_solver_list(),solver_type) do
      true ->  Colins.Solvers.ImplicitSolverServer.run_edges(Map.get(partition,"solver_id"),next_timepoint,current_step_size)
    end

  end

  @doc "Update the last completed map, delete the old one and add the new one"
  def update_last_completed_timepoints(state,partitions,timepoint) do

    current_step_size = Map.get(state,"current_step_size")

    last_completed_timepoints = Map.get(state,"last_completed_timepoints")

    last_completed_timepoints = Enum.reduce(partitions,last_completed_timepoints,fn(partition,acc) ->
      Map.put(acc,partition,timepoint)
    end)

    Map.put(state,"last_completed_timepoints",last_completed_timepoints)

  end

  @doc "This only runs when the current_step_size is not the smallest_step_size and there is more than 1 step_size"
  def set_next_largest_step_size(state) do

    current_step_size = Map.get(state,"current_step_size")

    Logger.debug("\nset_next_largest_step_size: " <> inspect(current_step_size))

    # Get a list of step_sizes, ordered small to big
    step_size_list = Enum.sort(Map.keys(Map.get(state,"step_size_map")))

    Logger.debug("\nstep_size_list: " <> inspect(step_size_list))

    # Find the list index of the current_step_size
    #current_step_size_index = Enum.find_index(step_size_list,fn(x) -> x == current_step_size end)
    current_step_size_index = Enum.find_index(step_size_list,fn(x) -> match?(x,current_step_size) end)

    Logger.debug("\ncurrent_step_size_index: " <> inspect(current_step_size_index))

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

    string = ""

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

    # Simulation execution length in microseconds
    string = string <> "simulation_initialisation_time_microseconds," <> Integer.to_string(Map.get(state,"simulation_initialisation_time_microseconds")) <> "\n"
    string = string <> "simulation_execution_length_microseconds," <> Integer.to_string(Map.get(state,"simulation_execution_length_microseconds")) <> "\n"
    string = string <> "simulation_export_time_microseconds," <> Integer.to_string(Timex.diff(Timex.now(),Map.get(state,"simulation_export_time_microseconds"))) <> "\n"


    IO.write(file,string)
    File.close(file)

  end

  def finish_simulation(state) do

    state = Map.put(state,"simulation_export_time_microseconds",Timex.now())

    # Write out benchmark data
    state = Map.put(state,"simulation_end_time",Timex.now())
    state = Map.put(state,"simulation_execution_length_microseconds",Timex.diff(Map.get(state,"simulation_end_time"),Map.get(state,"simulation_start_time")))

    Logger.info("\nsimulation finished")

    IO.inspect("simulation finished")

    IO.inspect(state)

    # Tell all the edges to write to file.
    Enum.map(Map.get(state,"partitions"),fn({_partition_id,partition_data}) ->

      Colins.Solvers.SolverServer.write_edges(Map.get(partition_data,"solver_id"))
    end)

    Colins.Nodes.Controller.write_results_to_file()

    write_out_benchmark_data(state)

    state

  end


  def handle_cast(:notify_node_commit_complete,state) do

    # If there is more than 1 partition (ie more than 1 rate - run this as a multi-rate version)
    state = case Map.get(state,"number_of_partitions") do

      x when x > 1 -> multi_rate_interpolate(state)
      _ -> run_next_step(state)

    end

    # Wait for the interpolation to finish.
    {:noreply, state}

  end

  def handle_cast(:notify_node_interpolation_complete,state) do

    {:noreply,run_next_step(state)}

  end

  def handle_cast({:setup_simulation,sim_id,results_folder,partitions,max_timepoint,mesh_size},state) do

    state = Map.put(state,"mesh_size",mesh_size)
    #state = Map.put(state,"explicit_implicit_switch_step_size_tolerance",1.0e-6)
    state = Map.put(state,"step_size_decimal_places",calculate_step_size_decimal_places(mesh_size,1.0e-6))
    state = Map.put(state,"sim_id",sim_id)
    state = Map.put(state,"results_folder",results_folder)

    state = Map.put(state,"max_timepoint",max_timepoint/1)

    state = Map.put(state,"partitions",partitions)

    step_size_map = build_step_size_map(partitions)

    state = Map.put(state,"step_size_map",step_size_map)

    state = Map.put(state,"completed_timepoints",%{})

    state = Map.put(state,"current_timepoint",0.0)

    state = Map.put(state,"current_step_size",List.last(Enum.sort(Map.keys(step_size_map))))
    state = Map.put(state,"smallest_step_size",List.first(Enum.sort(Map.keys(step_size_map))))

    state = Map.put(state,"update_current_timepoint",:false)

    state = Map.put(state,"sim_complete",:false)

    state = Map.put(state,"last_completed_timepoints",%{})

    state = Map.put(state,"running_partitions",[])

    state = Map.put(state,"number_of_partitions",map_size(partitions))

    #IO.inspect(state)

    {:noreply,state}

  end

  def handle_cast({:set_simulation_initialisation_time_microseconds,simulation_initialisation_time_microseconds},state) do

    {:noreply,Map.put(state,"simulation_initialisation_time_microseconds",simulation_initialisation_time_microseconds)}

  end


  def handle_cast(:start_simulation,state) do

    state = Map.put(state,"simulation_start_time",Timex.now())

    {:noreply,run_new_timepoint(state,0.0)}

  end

  def handle_cast({:notify_edges_complete},state) do

    Colins.Nodes.Controller.commit_timepoint_queue()

    {:noreply,state}

  end

  def handle_cast({:notify_edges_complete_with_step_size_change,new_step_size,partition_id},state) do

    # Update the step sizes for this partition
    # Check whether it is the correct one to run (based on largest first).
    # Rerun step.

    #mesh_size = Map.get(state,"mesh_size")
    #explicit_implicit_switch_step_size_tolerance = 1.0e-6

    #explicit_implicit_switch_step_size_tolerance = Map.get(state,"explicit_implicit_switch_step_size_tolerance")
    explicit_implicit_switch_step_size_tolerance = Map.get(Map.get(Map.get(state,"partitions"),partition_id),"explicit_implicit_switch_step_size_tolerance")

    # IO.inspect("explicit_implicit_switch_step_size_tolerance")
    #IO.inspect(explicit_implicit_switch_step_size_tolerance)

    # if the step size is smaller than the 1.0e-6, then move to the implicit backward euler.
    state = case {new_step_size,explicit_implicit_switch_step_size_tolerance} do

      {a,b} when (a <= b) -> # Move to the implicit solver
        move_partition_to_implicit_solver(state,new_step_size,partition_id)
      _ -> # Update the step sizes for the explicit solver
        update_step_sizes_and_rerun_step(state,new_step_size,partition_id)

    end

    {:noreply,state}

  end

end