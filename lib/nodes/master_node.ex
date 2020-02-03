require Logger
require Mix

defmodule Colins.Nodes.MasterNode do

    use GenServer


    @moduledoc "

        Master Node for the stateful node system

        Receives writes, and when caching, forwards to cache nodes.

        node_id = :ncb_name

        Backend - (.txt from this file).

        timepoint_data = %{0 => 0, 1 => 20}  etc

        Hash                 Int   List
        uncommitted_rates = %{2 => [1,2.3,3]} etc

        Committing rates

        Loop over the uncommitted rates queues and commit the rates for each timepoint.

        At the end of the 'commit rates' method, delete the uncommitted_rates.

        Interpolate function

        Take the interpolate period start timepoint value
        Take the interpolate period end timepoint value

        Divide the difference between these values by the number of smallest steps between them.

        Add the value of this to each smallest timepoint between them.

        Send message back that it has completed.

        TODO: Move the entire node system to streams.

    "


    def start_link(node_id) do

        GenServer.start_link(__MODULE__,node_id,[name: node_id])

    end

    def init(node_id) do

        state = %{"node_id" => node_id,
                  "timepoint_data" => %{},
                  "uncommitted_rates" => %{},
                  "results_folder_path" => nil,
                  "cache_id_list" => [],
                  "solver_scratchpad" => %{}}

        Logger.info("\nNODE " <> Atom.to_string(node_id) <> " INITIALISING")

        {:ok, state}

    end

    def prepare(node_id,initial_value,results_folder_path,cache_id_list) do

        GenServer.cast(node_id,{:prepare,initial_value,results_folder_path,cache_id_list})

    end

    def reset_timestep_data(node_id) do

        GenServer.cast(node_id,:reset_timestep_data)
    end

    def interpolate_data(node_id,mesh_size,start_timepoint,end_timepoint) do

        GenServer.cast(node_id,{:interpolate_data,mesh_size,start_timepoint,end_timepoint})

    end

    def run_interpolation(state,mesh_size,start_timepoint,end_timepoint) do

        timepoint_data = Map.get(state,"timepoint_data")

        start_timepoint_value = Map.get(timepoint_data,start_timepoint)

        end_timepoint_value = Map.get(timepoint_data,end_timepoint)

        number_of_timepoints = Kernel.trunc(Float.round((end_timepoint - start_timepoint) / mesh_size,11))

        #IO.inspect(state)
        #IO.inspect(number_of_timepoints)

        divided_value = (end_timepoint_value - start_timepoint_value) / number_of_timepoints

        log_string = "\nRunning interpolation: - "
        log_string = log_string <> " - Start timepoint: " <> inspect(start_timepoint)
        log_string = log_string <> " - End timepoint: " <> inspect(end_timepoint)
        log_string = log_string <> " - Start timepoint value: " <> inspect(start_timepoint_value)
        log_string = log_string <> " - End timepoint value: " <> inspect(end_timepoint_value)
        log_string = log_string <> " - Number of timepoints: " <> inspect(number_of_timepoints)
        log_string = log_string <> " - Mesh size: " <> inspect(mesh_size)
        log_string = log_string <> " - Divided value: " <> inspect(divided_value)

        Logger.debug(log_string)

        # 1. Build new timepoint map

        timepoint_data = Enum.reduce(0..(number_of_timepoints - 1),timepoint_data,fn(timestep,acc) ->

            timepoint = Float.round((timestep * mesh_size) + start_timepoint,11)

            # Check if the timepoint has any data
            new_value = case Map.has_key?(timepoint_data,timepoint) do

                true -> (Map.get(timepoint_data,timepoint) / 1) + ((timestep * divided_value))
                false -> (timestep * divided_value) + start_timepoint_value

            end

            pos_value = case new_value do

                x when x < 0 -> 0.0

                _ ->  new_value

            end

            Map.put(acc,timepoint,pos_value)

        end)

        Logger.debug("\n timepoint data: " <> inspect(timepoint_data))

        Map.put(state,"timepoint_data",timepoint_data)

    end

    @doc "Get the current value"
    def get_scratchpad_var(node_id,solver_id,variable_name) do

         GenServer.call(node_id,{:get_scratchpad_var,solver_id,variable_name})
    end

    def get_subfunction_plus_timepoint_data(node_id,solver_id,variable_name,timepoint) do

        GenServer.call(node_id,{:get_subfunction_plus_timepoint_data,solver_id,variable_name,timepoint})

    end

    #TODO: Implement a version to return multiple scratchpad vars if necessary
    @doc "Function to return the timepoint data necessary scratchpad data. Only returns 1 variable name"
    def get_timepoint_data_and_subfunction_value(node_id,timepoint,solver_id,variable_name) do

        GenServer.call(node_id,{:get_timepoint_data_and_subfunction_value,timepoint,solver_id,variable_name})
    end

    def increment_timepoint_value(node_id,timepoint,value) do

        GenServer.cast(node_id,{:increment_timepoint_value,timepoint,value})

    end

    @doc "commit the rates from this step"
    def commit_all_rates(node_id) do

        GenServer.cast(node_id,{:commit_all_rates})

    end


    def write_to_file(node_id,results_path) do

        GenServer.cast(node_id,{:write_to_file,results_path,node_id})

    end


    @doc "Get the current value"
    def get_timepoint_data(node_id,timepoint) do

        GenServer.call(node_id,{:get_timepoint_data,timepoint})
    end

    @doc "Function to return the timepoint data necessary scratchpad data. Only returns Map of variable names, variable values, and current timepoint value"
    def get_timepoint_data_and_multiple_subfunction_values(node_id,timepoint,solver_id,variable_names) do

        GenServer.call(node_id,{:get_timepoint_data_and_multiple_subfunction_values,timepoint,solver_id,variable_names})
    end


    def set_scratchpad_var(node_id,solver_id,variable_name,variable_value) do

        GenServer.cast(node_id,{:set_scratchpad_var,solver_id,variable_name,variable_value})

    end

    def handle_call({:get_scratchpad_var,solver_id,variable_name},_from,state) do

        #solver_scratchpad = Map.get(state,"solver_scratchpad")
        #solver_data = Map.get(Map.get(state,"solver_scratchpad"),solver_id)

        variable_value = Map.get(Map.get(Map.get(state,"solver_scratchpad"),solver_id),variable_name)

        {:reply,variable_value,state}
    end

    @doc "Get the timepoint data."
    def handle_call({:get_subfunction_plus_timepoint_data,solver_id,variable_name,timepoint},_from,state) do

        variable_value = Map.get(Map.get(Map.get(state,"solver_scratchpad"),solver_id),variable_name)

        timepoint_data = Map.get(state,"timepoint_data")

        timepoint = Float.round((timepoint / 1),11)

        timepoint_value = case Map.has_key?(timepoint_data,timepoint) do

            true -> Map.get(timepoint_data,timepoint)
            false -> nil
        end

        {:reply,(variable_value + timepoint_value),state}

    end


    def handle_call({:get_timepoint_data_and_subfunction_value,timepoint,solver_id,variable_name},_from,state) do

        variable_value = Map.get(Map.get(Map.get(state,"solver_scratchpad"),solver_id),variable_name)

        timepoint_data = Map.get(state,"timepoint_data")

        timepoint = Float.round((timepoint / 1),11)

        timepoint_value = case Map.has_key?(timepoint_data,timepoint) do

            true -> Map.get(timepoint_data,timepoint)
            false -> nil
        end

        {:reply,{timepoint_value,variable_value},state}

    end


    def handle_call({:get_timepoint_data_and_multiple_subfunction_values,timepoint,solver_id,variable_names},_from,state) do

        solver_scratchpad = Map.get(state,"solver_scratchpad")
        scratchpad = Map.get(solver_scratchpad,solver_id)

        scratchpad_data = Enum.reduce(variable_names,%{},fn(variable_name,acc) ->

            Map.put(acc,variable_name,Map.get(scratchpad,variable_name))

        end)

        timepoint_data = Map.get(state,"timepoint_data")

        timepoint = Float.round((timepoint / 1),11)

        timepoint_value = case Map.has_key?(timepoint_data,timepoint) do

            true -> Map.get(timepoint_data,timepoint)
            false -> nil
        end

        scratchpad_data = Map.put(scratchpad_data,"timepoint_value",timepoint_value)

        #IO.inspect(scratchpad_data)

        {:reply,scratchpad_data,state}

    end


    @doc "Get the timepoint data."
    def handle_call({:get_timepoint_data,timepoint},_from,state) do

        Logger.debug("\n Get timepoint received. timepoint: " <> inspect(timepoint))

        timepoint_data = Map.get(state,"timepoint_data")

        timepoint = Float.round((timepoint / 1),11)

        timepoint_value = case Map.has_key?(timepoint_data,timepoint) do

            true -> Map.get(timepoint_data,timepoint)
            false -> nil
        end

        Logger.debug(timepoint)
        Logger.debug(timepoint_value)

        {:reply,timepoint_value,state}

    end

    def commit_timepoint_data(edge_id,timepoint) do

        GenServer.cast(edge_id,{:commit_timepoint_data,timepoint})

    end

     @doc "Interpolation method "
    def handle_cast({:interpolate_data,mesh_size,start_timepoint,end_timepoint},state) do

        state = run_interpolation(state,mesh_size,start_timepoint,end_timepoint)

        Logger.debug("\n Post interpolation state: " <> inspect(state))

        Colins.Nodes.Controller.node_interpolation_complete(Map.get(state,"node_id"))

        {:noreply,state}
    end


    @doc "Callback to initialise heartbeat system"
    def handle_cast({:prepare,initial_value,results_folder_path,cache_id_list},state) do

        state = Map.put(state,"results_folder_path",results_folder_path)

        state = Map.put(state,"cache_id_list",cache_id_list)

        timepoint_data = Map.get(state,"timepoint_data")
        timepoint_data = Map.put(timepoint_data,0.0,(initial_value/1))
        state = Map.put(state,"timepoint_data",timepoint_data)

        {:noreply,state}

    end
    
    def handle_cast({:increment_timepoint_value,timepoint,value},state) do

        all_uncommitted_rates = Map.get(state,"uncommitted_rates")

        float_timepoint = timepoint / 1

        Logger.debug("\n timepoint: " <> inspect(timepoint) <> " value: " <> inspect(value))

        this_timepoint_uncommitted_rates = case Map.has_key?(all_uncommitted_rates,float_timepoint) do

            true -> [ value | Map.get(all_uncommitted_rates,float_timepoint)]
            false -> [ value ]

        end

        all_uncommitted_rates = Map.put(all_uncommitted_rates,float_timepoint,this_timepoint_uncommitted_rates)

        state = Map.put(state,"uncommitted_rates",all_uncommitted_rates)

        Logger.debug("\nUncommitted rate added: " <> inspect(timepoint) <> " - " <> inspect(value))

        {:noreply,state}

    end


    @doc "Commit the rates. Loop over the uncommitted rates queues and commit the rates for this timepoint"
    def handle_cast({:commit_all_rates},state) do

        #TODO: Turn this into a stream. It will massively increase performance.
      #  IO.inspect("what")
      #  IO.inspect(state)

        all_uncommitted_rates = Map.get(state,"uncommitted_rates")
        timepoint_data = Map.get(state,"timepoint_data")

        new_timepoint_data = Enum.reduce(all_uncommitted_rates,timepoint_data,fn({timepoint,rates},tacc) ->

            current_value = case Map.has_key?(timepoint_data,timepoint) do

                true -> Map.get(timepoint_data,timepoint) / 1
                false -> 0.0

            end

            #current_value = Map.get(timepoint_data,timepoint) / 1

            new_value = Enum.reduce(rates,current_value,fn(rate,acc) ->

                acc + rate
            end)

            pos_value = case new_value do

                x when x < 0 -> 0.0

                _ -> new_value / 1

            end

            Map.put(tacc,timepoint,pos_value)

        end)

        #IO.inspect(new_timepoint_data)

        state = Map.put(state,"timepoint_data",new_timepoint_data)

        state = Map.put(state,"uncommitted_rates",%{})

        state = case Application.get_env(:logger,:level) do
            :prod -> Map.put(state,"solver_scratchpad",%{})
            _ -> state
        end

        Colins.Nodes.Controller.notify_node_commit_complete(Map.get(state,"node_id"))

        {:noreply,state}

    end

    def handle_cast({:write_to_file,results_folder_path,node_id},state) do

        #folder_path = case entity_type do

        #    "node" -> Path.join([results_folder_path,"node_data",process_id])
        #    "edge" -> Path.join([results_folder_path,"edge_data",process_id])

        #end

        #IO.inspect(Enum.sort(Map.get(state,"timepoint_data")))

        File.mkdir_p!(results_folder_path)

        file_path = Path.join([results_folder_path,"no_" <> Atom.to_string(node_id) <> ".txt"])

        timepoint_data = Map.get(state,"timepoint_data")

        ##IO.inspect(timepoint_cache)

        file = File.open!(file_path, [:write])

        #File.write!(file_path,"timepoint,value \n")
        IO.write(file,"timepoint,value\n")

        Enum.map(Enum.sort(Map.keys(timepoint_data)),fn(timepoint) ->

            value = Map.get(timepoint_data,timepoint)

            float_val = value / 1

            string = Float.to_string((timepoint / 1)) <> "," <> Float.to_string(float_val) <> " \n"
         #   File.write!(file_path,string)
            IO.write(file,string)

        end)

        File.close(file)

        Colins.Nodes.Controller.notify_file_write_complete(node_id)

#        IO.inspect(Atom.to_string(node_cache_id) <> " file write complete!")

        {:noreply,state}
    end


end