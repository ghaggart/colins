require Logger

defmodule Colins.Nodes.Controller do
  @moduledoc false

  use GenServer

  # Must implement start_link
    def start_link() do

        # Call the Supervisor method
        GenServer.start_link(__MODULE__,[], name: __MODULE__)

    end

    # Init is called
    def init([]) do

        {:ok,%{}}
    end

    def setup(node_map,sim_id,results_folder) do

        GenServer.cast(__MODULE__,{:setup,node_map,sim_id,results_folder})

    end

    def reset_timestep_data() do

        GenServer.cast(__MODULE__,:reset_timestep_data)

    end

    def interpolate_all_nodes(mesh_size,start_timepoint,end_timepoint) do

        GenServer.cast(__MODULE__,{:interpolate_all_nodes,mesh_size,start_timepoint,end_timepoint})

    end

    def node_interpolation_complete(node_id) do

        GenServer.cast(__MODULE__,{:node_interpolation_complete,node_id})

    end

    def commit_timepoint_queue() do

        GenServer.cast(__MODULE__,{:commit_timepoint_queue})

    end

    def notify_node_commit_complete(node_id) do

         GenServer.cast(__MODULE__,{:node_commit_complete,node_id})

    end

    def write_results_to_file() do

        GenServer.cast(__MODULE__,:write_results_to_file)

    end


    def notify_file_write_complete(node_id) do

        GenServer.cast(__MODULE__,{:file_write_complete,node_id})

    end

    def run_another_node_write(state) do

        sim_id = Map.get(state,"sim_id")

        results_folder = Map.get(state,"results_folder")

        results_path = Path.join(results_folder,sim_id)

        node_write_complete_map = Map.get(state,"node_write_complete_map")

        # FIND THE FIRST NEXT ELEMENT THAT IS :not_run, RUN IT AND BREAK.

        {node_id,_} = Enum.find(node_write_complete_map,fn({_node_id,write_status}) ->

            write_status == :not_run

        end)

        Colins.Nodes.MasterNode.write_to_file(node_id,results_path)

        node_write_complete_map = Map.put(node_write_complete_map,node_id,:running)

        state = Map.put(state,"node_write_complete_map",node_write_complete_map)

        state

    end

    def handle_cast(:reset_timestep_data,state) do

        Enum.map(Map.get(state,"node_map"),fn({node_id,_node_data}) ->

            Colins.Nodes.MasterNode.reset_timestep_data(node_id)
        end)
        {:noreply,state}

    end

    def handle_cast({:setup,node_map,sim_id,results_folder},state) do

        state = Map.put(state,"node_map",node_map)
        state = Map.put(state,"sim_id",sim_id)
        state = Map.put(state,"results_folder",results_folder)

        node_job_completion_record = Enum.reduce(node_map,%{},fn({node_id,_data},acc) ->

            Map.put(acc,node_id,:complete)
        end)

        state = Map.put(state,"node_job_completion_record",node_job_completion_record)

        ##IO.inspect(state)

        {:noreply,state}
    end

    def handle_cast({:interpolate_all_nodes,mesh_size,start_timepoint,end_timepoint},state) do

        Logger.debug("\nInterpolating all nodes...")

        node_map = Map.get(state,"node_map")

        #Colins.Nodes.MasterNode.interpolate_data(:node_two,smallest_step_size,stepper_timepoint)

        node_job_completion_record = Enum.reduce(node_map,%{},fn({node_id,_node_data},acc) ->

            # If this is the special timepoint node - do not interpolate
            case node_id do

              :timepoint -> acc
              _ -> Colins.Nodes.MasterNode.interpolate_data(node_id,mesh_size,start_timepoint,end_timepoint)
                   Map.put(acc,node_id,:running)

            end

        end)

        state = Map.put(state,"node_job_completion_record",node_job_completion_record)

        {:noreply,state}
    end

    # At the moment this is using the node_job_completion_record.
    def handle_cast({:node_interpolation_complete,node_id},state) do

        node_job_completion_record = Map.get(state,"node_job_completion_record")

        node_job_completion_record = Map.put(node_job_completion_record,node_id,:complete)

        state = Map.put(state,"node_job_completion_record",node_job_completion_record)

        case Enum.member?(Map.values(node_job_completion_record),:running) do

           true -> nil
           false -> Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_node_interpolation_complete()

        end

        {:noreply,state}
    end


    def handle_cast({:commit_timepoint_queue},state) do

        Logger.debug("\nCommitting timepoint queue...")

        node_map = Map.get(state,"node_map")

        node_job_completion_record = Enum.reduce(node_map,%{},fn({node_id,_node_data},acc) ->

            #Colins.Nodes.MasterNode.commit_rates(node_id,timepoint,step_size,smallest_step_size)
            Colins.Nodes.MasterNode.commit_all_rates(node_id)
            Map.put(acc,node_id,:running)

        end)

        state = Map.put(state,"node_job_completion_record",node_job_completion_record)

        {:noreply,state}
    end


    def handle_cast({:node_commit_complete,node_id},state) do

        node_job_completion_record = Map.get(state,"node_job_completion_record")

        node_job_completion_record = Map.put(node_job_completion_record,node_id,:complete)

        state = Map.put(state,"node_job_completion_record",node_job_completion_record)

        case Enum.member?(Map.values(node_job_completion_record),:running) do

           true -> nil
           false -> Colins.Timesteps.AdaptiveMultiRateTimestepController.notify_node_commit_complete()

        end

        {:noreply,state}
    end

    def handle_cast(:write_results_to_file,state) do

        sim_id = Map.get(state,"sim_id")

        results_folder = Map.get(state,"results_folder")

        results_path = Path.join(results_folder,sim_id)

        # Build the entire map

        node_write_complete_map = Enum.reduce(Map.get(state,"node_map"),%{},fn({node_id,_data},acc) ->

            #Colins.Nodes.NodeTimepointCache.write_to_file(node_cache_id,results_folder)

            Map.put(acc,node_id,:not_run)
        end)

        # Get the chunk size for File IO limit
        length_of_map = length(Map.keys(node_write_complete_map))

        chunk_size = case length(Map.keys(node_write_complete_map)) do

            length_of_map when length_of_map >= 200 -> 200
            _ -> length_of_map

        end

        Logger.info("\nTotal number of nodes: " <> Integer.to_string(length_of_map))
        Logger.info("\nChunk size: " <> Integer.to_string(chunk_size))

        chunked_map_list = Enum.chunk(node_write_complete_map,chunk_size)

        first_chunk = List.first(chunked_map_list)

        node_write_complete_map = Enum.reduce(first_chunk,node_write_complete_map,fn({node_id,_status},acc) ->

            Colins.Nodes.MasterNode.write_to_file(node_id,results_path)
            Map.put(acc,node_id,:running)
        end)

        state = Map.put(state,"node_write_complete_map",node_write_complete_map)

        {:noreply,state}
    end

    def handle_cast({:file_write_complete,node_id},state) do

        node_write_complete_map = Map.get(state,"node_write_complete_map")

        node_write_complete_map = Map.put(node_write_complete_map,node_id,:complete)

        state = Map.put(state,"node_write_complete_map",node_write_complete_map)

        # Check for running and not run entries
        state = case {Enum.member?(Map.values(node_write_complete_map),:running),Enum.member?(Map.values(node_write_complete_map),:not_run)} do

           {true,false} -> state
           {_,true} -> run_another_node_write(state)
           {false,false} -> Colins.MainController.stop_simulator()
                            state

        end

        #total_nodes = length(Map.keys(node_write_complete_map))
      #  IO.inspect(Enum.member?(Map.values(node_write_complete_map),:running))
      #  IO.inspect(Enum.member?(Map.values(node_write_complete_map),:not_run))

  #     IO.inspect(Atom.to_string(node_cache_id))

        {:noreply,state}
    end


end