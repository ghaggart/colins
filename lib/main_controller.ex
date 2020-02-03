import Supervisor.Spec
use Timex
require Logger

defmodule Colins.MainController do
    @moduledoc """

    MainController. Configure and run a simulation.


    Timepoint = The current timepoint of the simulation. eg 0, 0.32, 0.5,0.64 etc
    Timestep = The current timestep of the simulation. eg 0,1,2,3,4,5,6,7

    """

    use GenServer

    @doc " Connect this with the supervisor "
    def start_link() do

        # Call the Supervisor method
        GenServer.start_link(__MODULE__,[], name: __MODULE__)

    end

    @doc " Initialise the state "
    def init([]) do

        state = %{"stepper_map" => %{}}

        {:ok,state}
    end

    @doc " Setup the simulation. Build the steppers and node-edge topology. "
    def setup_simulation(options) do

        GenServer.call(__MODULE__,{:setup_simulation,options})

    end

    def handle_call({:setup_simulation,options},_from,state) do

        # Configure logger
        Logger.configure_backend(
            {LoggerFileBackend, :debug_log},
            path: Path.join([Map.get(options,"results_folder"),Map.get(options,"sim_id"),"debug.log"]),
        )

        Logger.info("\nSimulation options: " <> inspect(options))
        IO.inspect("Simulation options: ")
        IO.inspect(options)

        Logger.info("\nConfiguring network..... ")
        IO.inspect("Configuring network..... ")

        simulation_initialisation_time_microseconds = Timex.now()

        state = build_network(options,state)

        simulation_initialisation_time_microseconds = Timex.diff(Timex.now(),simulation_initialisation_time_microseconds)
        Colins.Timesteps.AdaptiveMultiRateTimestepController.set_simulation_initialisation_time_microseconds(simulation_initialisation_time_microseconds)

        write_options_to_file(options)

#        {:ok, time_str} = Timex.format(Timex.now, "{ISO:Extended}")
#        IO.inspect(time_str <> " ...done")
        Logger.info("\n ...done")
        IO.inspect(" .....done")

        {:reply,:true,state}
    end

    def build_network(options,state) do

        state = Map.put(state,"options",options)

        state = build_partition_edge_map(state)

        build_nodes(state)

        build_edge_data_servers(state)

        state = build_solver_servers(state)

        build_timestep_controller_and_edges(state)

        #build_solver_servers(state)

        state

    end

    def build_nodes(state) do

        options = Map.get(state,"options")
        sim_id = Map.get(options,"sim_id")
        results_folder = Map.get(options,"results_folder")

        nodes = Map.get(Map.get(options,"network_topology"),"nodes")

        Supervisor.start_child(Colins.Supervisors.NodeSupervisor, worker(Colins.Nodes.Controller,[]))

        Colins.Nodes.Controller.setup(nodes,sim_id,results_folder)

        Enum.map(nodes,fn({node_id,config}) ->

           # node_cache_id = String.to_atom(Atom.to_string(node_id) <> "_TC")

            # TODO: Add cache nodes here.

            Supervisor.start_child(Colins.Supervisors.NodeSupervisor, worker(Colins.Nodes.MasterNode,[node_id], id: node_id))

            initial_value = Map.get(config,"initial_value")
            Colins.Nodes.MasterNode.prepare(node_id,initial_value,results_folder,[])

        end)

    end

    def build_edge_data_servers(state) do

        options = Map.get(state,"options")
        results_folder = Path.join(Map.get(options,"results_folder"),Map.get(options,"sim_id"))

        edges = Map.get(Map.get(options,"network_topology"),"edges")

        Supervisor.start_child(Colins.Supervisors.NodeSupervisor,worker(Colins.Edges.PartitionEdgeDB,[]))

        partition_map = Enum.reduce(edges,%{},fn({edge_id,edge_data},acc) ->

            Supervisor.start_child(Colins.Supervisors.NodeSupervisor, worker(Colins.Edges.EdgeData,[edge_id], id: edge_id))
            Colins.Edges.EdgeData.prepare(edge_id,results_folder)
            Map.put(acc,Map.get(edge_data,"partition"),edge_data)
        end)

        Colins.Edges.PartitionEdgeDB.setup(partition_map)
    end


    def build_timestep_controller_and_edges(state) do

        options = Map.get(state,"options")
        network_topology = Map.get(options,"network_topology")

        Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Timesteps.AdaptiveMultiRateTimestepController,[]))
        Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Timesteps.TimestepData,[]))

        Colins.Timesteps.AdaptiveMultiRateTimestepController.setup_simulation(Map.get(options,"sim_id"),Map.get(options,"results_folder"),Map.get(network_topology,"partitions"),Map.get(options,"max_timepoint"),Map.get(options,"mesh_size"))
        Colins.Timesteps.TimestepData.prepare(Map.get(options,"sim_id"),Map.get(options,"results_folder"))

    end

    @doc "Builds a map with following structure:
            %{solver_id => %{edge_id => edge_data}

            solver_id is unique per partition
    "
    def build_partition_edge_map(state) do

        options = Map.get(state,"options")

        network_topology = Map.get(options,"network_topology")
        edges = Map.get(network_topology,"edges")
        partitions = Map.get(network_topology,"partitions")

        partition_edge_map = Enum.reduce(edges,%{},fn({edge_id,edge_data},acc) ->

            partition_id = Map.get(edge_data,"partition")

            partition_data = Map.get(partitions,partition_id)

            solver_id = Map.get(partition_data,"solver_id")

            case Map.has_key?(acc,solver_id) do

              # There is already as start_step_size here
                true -> partition_map = Map.put(Map.get(acc,solver_id),edge_id,edge_data)
                        Map.put(acc,solver_id,partition_map)

                false -> partition_map = Map.put(%{},edge_id,edge_data)
                        Map.put(acc,solver_id,partition_map)

            end

        end)

        Map.put(state,"partition_edge_map",partition_edge_map)

    end

    def build_solver_servers(state) do

        #IO.inspect(state)

        options = Map.get(state,"options")

        network_topology = Map.get(options,"network_topology")

        edges = Map.get(network_topology,"edges")

        partitions = Map.get(network_topology,"partitions")

        partition_edge_map = Map.get(state,"partition_edge_map")

        mesh_size = Map.get(options,"mesh_size")

        new_partition_map = Enum.reduce(partition_edge_map,%{},fn({solver_id,edge_map},acc) ->

            # get the first edge from the map and use that ID the data - they are all grouped by partition_id
            partition_id = Map.get(Map.get(edge_map,List.first(Map.keys(edge_map))),"partition")
            partition_data = Map.get(partitions,partition_id)

            #IO.inspect("starting child")

            partition_data = build_solver_servers_for_partition(Map.get(partition_data,"solver_type"),solver_id,partition_data,partition_id,mesh_size,edge_map,Map.get(partition_data,"local_error_minimum"),Map.get(partition_data,"local_error_maximum"),Colins.Solvers.Utils.get_explicit_solver_list(),Colins.Solvers.Utils.get_implicit_solver_list())

            Map.put(acc,partition_id,partition_data)

        end)

        state = Map.put(state,"options",Map.put(options,"network_topology",Map.put(network_topology,"partitions",new_partition_map)))

        new_edge_map = Enum.reduce(new_partition_map,%{},fn({partition_id,partition_data},acc) ->

            existing_edge_data = Map.get(partition_edge_map,Map.get(partition_data,"solver_id"))

            Map.put(acc,Map.get(partition_data,"explicit_solver_id"),existing_edge_data)
        end)

        state = Map.put(state,"partition_edge_map",new_edge_map)


    end

    def build_solver_servers_for_partition("dODE",solver_id,partition_data,partition_id,mesh_size,edge_map,local_error_minimum,local_error_maximum,_explicit_list,_implicit_list) do

        [ solver_type | tail ] = String.split(Atom.to_string(solver_id),"_")

        explicit_solver_id = String.to_atom("RungeKuttaFehlberg_" <> Enum.join(tail,"_"))
        implicit_solver_id = String.to_atom("BackwardEuler_" <> Enum.join(tail,"_"))

        Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Solvers.ExplicitSolverServer,[explicit_solver_id,"RungeKuttaFehlberg",partition_id,mesh_size,edge_map,local_error_maximum,local_error_minimum], id: explicit_solver_id))
        Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Solvers.ImplicitSolverServer,[implicit_solver_id,"BackwardEuler",partition_id,mesh_size,edge_map,local_error_maximum,local_error_minimum], id: implicit_solver_id))

        partition_data = Map.put(partition_data,"explicit_solver_type","RungeKuttaFehlberg")
        partition_data = Map.put(partition_data,"explicit_solver_id",explicit_solver_id)
        partition_data = Map.put(partition_data,"implicit_solver_type","BackwardEuler")
        partition_data = Map.put(partition_data,"implicit_solver_id",implicit_solver_id)
        partition_data = Map.put(partition_data,"solver_type_running","explicit")

    end

    def build_solver_servers_for_partition(solver_type,solver_id,partition_data,partition_id,mesh_size,edge_map,local_error_minimum,local_error_maximum,explicit_list,implicit_list) do

        case Enum.member?(explicit_list,solver_type) do
            true -> Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Solvers.ExplicitSolverServer,[solver_id,solver_type,partition_id,mesh_size,edge_map,local_error_maximum,local_error_minimum], id: solver_id))
            false -> nil
        end

        case Enum.member?(implicit_list,solver_type) do
            true -> Supervisor.start_child(Colins.Supervisors.SimulationSupervisor, worker(Colins.Solvers.ImplicitSolverServer,[solver_id,solver_type,partition_id,mesh_size,edge_map,local_error_maximum,local_error_minimum], id: solver_id))
            false -> nil
        end

        partition_data

    end

    def get_unique_solvers(edges) do

        #IO.inspect(edges)

        unique_solvers = Enum.reduce(edges,[],fn({_edge_id,edge_data},acc) ->

            solver = Map.get(edge_data,"solver")

            solver_id = Map.get(solver,"solver_id")

            case Enum.member?(acc,solver_id) do

                true -> acc
                false -> [ solver_id | acc ]

            end
        end)

        Logger.info("\nUnique solvers: " <> inspect(unique_solvers))

        unique_solvers

    end

    @doc """
        Builds the stepper timepoint map

        ie %{step_size => next_timepoint}
    """
    def build_stepper_timepoint_map(stepper_map) do

        Enum.reduce(stepper_map,%{},fn({step_size,_},acc) ->

            Map.put(acc,step_size,step_size)
        end)

    end

    def write_options_to_file(options) do

        options = Map.put(options,"active_schedulers",System.schedulers_online)

        sim_id = Map.get(options,"sim_id")
        results_folder = Map.get(options,"results_folder")

        results_path = Path.join(results_folder,sim_id)

        File.mkdir_p!(results_path)

        # Write out the config to an erlang binary file
        File.write!(Path.join([results_path,"config.ext"]),:erlang.term_to_binary(options))

        File.write!(Path.join([results_path,"config.txt"]),:lists.flatten(:io_lib.format("~p",[options])))

    end


    def stop_simulator() do

        GenServer.cast(__MODULE__,:stop_simulation)

    end

    def handle_cast(:stop_simulation,state) do

        options = Map.get(state,"options")
        sim_id = Map.get(options,"sim_id")
        results_folder = Map.get(options,"results_folder")

        results_path = Path.join(results_folder,sim_id)

        sim_complete_file = Path.join([results_path,"sim_complete_file"])

        Logger.info("\n...File write complete... Goodbye!")

        IO.inspect("...File write complete... Goodbye!")

        File.touch!(sim_complete_file)

        {:noreply,state}

    end

end