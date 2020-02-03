require Logger

defmodule Colins.Edges.EdgeData do

  use GenServer

  @moduledoc "

      Data store for the edges. Store ki values for intermediate steps.

      Each individual edge has a store.

      Can be used to store error per step.

    "


  def start_link(edge_id) do

    GenServer.start_link(__MODULE__,edge_id,[name: edge_id])

  end

  def init(edge_id) do

    state = %{"edge_id" => edge_id,
              "timepoint_data" => %{},
              "results_folder_path" => nil,
              "edge_scratchpad" => %{}}

    Logger.info("\nEdge " <> Atom.to_string(edge_id) <> " INITIALISING")

    {:ok, state}

  end

  def prepare(edge_id,results_folder_path) do

    GenServer.cast(edge_id,{:prepare,results_folder_path})

  end

  @doc "Get the current value"
  def get_scratchpad_var(edge_id,variable_name) do

    GenServer.call(edge_id,{:get_scratchpad_var,variable_name})

  end

  @doc "Get the current value"
  def get_scratchpad_vars(edge_id,variable_names) do

    GenServer.call(edge_id,{:get_scratchpad_vars,variable_names})

  end

  def write_to_file(edge_id) do

    GenServer.cast(edge_id,{:write_to_file,edge_id})

  end


  @doc "Get the current value"
  def get_timepoint_data(edge_id,timepoint) do

    GenServer.call(edge_id,{:get_timepoint_data,timepoint})
  end

  def set_scratchpad_var(edge_id,variable_name,variable_value) do

    GenServer.cast(edge_id,{:set_scratchpad_var,variable_name,variable_value})

  end

  def set_scratchpad_vars(edge_id,variable_map) do

    GenServer.cast(edge_id,{:set_scratchpad_vars,variable_map})

  end

  def reset_timestep_data(edge_id) do

    GenServer.cast(edge_id,{:reset_timestep_data})

  end

  def handle_cast(:reset_timestep_data,state) do

    # Reset the uncommitted_rates and edge_scratchpad.

    state = Map.put(state,"edge_scratchpad",%{})

    {:noreply,state}

  end

  def commit_timepoint_data(edge_id,timepoint) do

    GenServer.cast(edge_id,{:commit_timepoint_data,timepoint})

  end

  def handle_cast({:commit_timepoint_data,timepoint},state) do

    # Reset the uncommitted_rates and edge_scratchpad.

    timepoint_data = Map.get(state,"timepoint_data")
    edge_scratchpad = Map.get(state,"edge_scratchpad")
    timepoint_data = Map.put(timepoint_data,Float.round(timepoint / 1,11),edge_scratchpad)
    state = Map.put(state,"timepoint_data",timepoint_data)

    state = Map.put(state,"edge_scratchpad",%{})

    #state = Map.put(state,Map.put(Map.get(state,"timepoint_data"),timepoint,Map.get(state,"edge_scratchpad")))

    {:noreply,state}

  end

  def handle_cast({:set_scratchpad_var,variable_name,variable_value},state) do


    edge_scratchpad = Map.get(state,"edge_scratchpad")

    # If the key doesnt exist, create it.
    edge_scratchpad = case edge_scratchpad do
      nil -> %{}
      _ -> edge_scratchpad
    end

    state = Map.put(state,"edge_scratchpad",Map.put(edge_scratchpad,variable_name,variable_value))

    {:noreply,state}

  end

  def handle_cast({:set_scratchpad_vars,variable_map},state) do

    edge_scratchpad = Map.get(state,"edge_scratchpad")

    # If the key doesnt exist, create it.
    edge_scratchpad = case edge_scratchpad do
      nil -> %{}
      _ -> edge_scratchpad
    end

    new_edge_scratchpad = Enum.reduce(variable_map,edge_scratchpad,fn({variable_name,variable_value},acc) ->
        Map.put(acc,variable_name,variable_value)
    end)

    state = Map.put(state,"edge_scratchpad",new_edge_scratchpad)

    {:noreply,state}

  end

  def handle_call({:get_scratchpad_var,variable_name},_from,state) do

    variable_value = Map.get(Map.get(state,"edge_scratchpad"),variable_name)

    {:reply,variable_value,state}
  end

  def handle_call({:get_scratchpad_vars,variable_names},_from,state) do

    variable_values = Enum.reduce(variable_names,%{},fn(variable_name,acc) ->

      Map.put(acc,variable_name,Map.get(Map.get(state,"edge_scratchpad"),variable_name))

    end)

    {:reply,variable_values,state}
  end

  @doc "Get the timepoint data."
  def handle_call({:get_timepoint_data,timepoint},_from,state) do

    Logger.debug("\n Get timepoint received. timepoint: " <> inspect(timepoint))

    all_timepoint_data = Map.get(state,"timepoint_data")

    timepoint = Float.round((timepoint / 1),11)

    timepoint_data = case Map.has_key?(all_timepoint_data,timepoint) do

      true -> Map.get(all_timepoint_data,timepoint)
      false -> nil
    end

    Logger.debug(timepoint_data)

    {:reply,timepoint_data,state}

  end


  @doc "Callback to initialise heartbeat system"
  def handle_cast({:prepare,results_folder_path},state) do

    state = Map.put(state,"results_folder_path",results_folder_path)

    {:noreply,state}

  end

  def handle_cast({:write_to_file,edge_id},state) do


    results_folder_path = Map.get(state,"results_folder_path")

    File.mkdir_p!(results_folder_path)

    file_path = Path.join([results_folder_path,"edge_" <> Atom.to_string(edge_id) <> ".txt"])

    IO.inspect(file_path)

    timepoint_data = Map.get(state,"timepoint_data")

    file = File.open!(file_path, [:write])

    #File.write!(file_path,"timepoint,value \n")
    IO.write(file,"timepoint,")

    # Build and write out the header string
    list_of_timepoints = Enum.sort(Map.keys(timepoint_data))

    second_element_keys = case length(list_of_timepoints) do

        0 -> []
        _ -> [ first | [ second | _ ]] = list_of_timepoints
             Map.keys(Map.get(timepoint_data,second))

    end

    header_string = Enum.reduce(second_element_keys,"",fn(key,acc) ->
      acc <> key <> ","
    end)

    IO.write(file,header_string <> "\n")

    # Build and write out each row
    Enum.map(Enum.sort(Map.keys(timepoint_data)),fn(timepoint) ->
      stored_values = Map.get(timepoint_data,timepoint)
      string_start = Float.to_string(timepoint) <> ","
      string = Enum.reduce(second_element_keys,string_start,fn(field_name,acc) ->
         field_value = Map.get(stored_values,field_name)
         acc <> Float.to_string(field_value) <> ","

      end)
      IO.write(file,string <> " \n")
    end)

    File.close(file)

    #Colins.Nodes.Controller.notify_file_write_complete(node_id)

    #        IO.inspect(Atom.to_string(node_cache_id) <> " file write complete!")

    {:noreply,state}
  end


end