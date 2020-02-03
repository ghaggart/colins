require Logger

defmodule Colins.Timesteps.TimestepData do

  use GenServer

  @moduledoc "

      Data store for the timesteps. ie benchmark data.

    "


  def start_link() do

    GenServer.start_link(__MODULE__,[],[name: __MODULE__])

  end

  def init([]) do

    state = %{"timepoint_data" => %{},
              "results_folder_path" => nil }

    Logger.info("\nTimestep Data Server INITIALISING")

    {:ok, state}

  end

  def prepare(sim_id,results_folder) do

    GenServer.cast(__MODULE__,{:prepare,sim_id,results_folder})

  end

  def write_to_file() do

    GenServer.cast(__MODULE__,:write_to_file)

  end

  def set_variable(timepoint,variable_name,variable_value) do

    GenServer.cast(__MODULE__,{:set_variable,timepoint,variable_name,variable_value})

  end

  def handle_cast({:set_variable,timepoint,variable_name,variable_value},state) do

    timepoint_data = Map.get(state,"timepoint_data")

    timepoint_variables = Map.get(timepoint_data,timepoint)

    # If the key doesnt exist, create it.
    timepoint_variables = case timepoint_variables do
      nil -> %{}
      _ -> timepoint_variables
    end

    #timepoint_variables = Map.put(timepoint_variables,variable_name,variable_value)
    #timepoint_data = Map.put(timepoint_data,timepoint,Map.put(timepoint_variables,variable_name,variable_value))

    #state = Map.put(state,"timepoint_data",timepoint_data)
    state = Map.put(state,"timepoint_data",Map.put(timepoint_data,timepoint,Map.put(timepoint_variables,variable_name,variable_value)))

    {:noreply,state}

  end


  @doc "Callback to initialise heartbeat system"
  def handle_cast({:prepare,sim_id,results_folder_path},state) do

    results_folder_path = Path.join([results_folder_path,sim_id])
    state = Map.put(state,"results_folder_path",results_folder_path)

    {:noreply,state}

  end

  def handle_cast(:write_to_file,state) do

    results_folder_path = Map.get(state,"results_folder_path")

    File.mkdir_p!(results_folder_path)

    file_path = Path.join([results_folder_path,"timestep_data.txt"])

   # IO.inspect(file_path)

    timepoint_data = Map.get(state,"timepoint_data")

    IO.inspect(state)

    file = File.open!(file_path, [:write])

    #File.write!(file_path,"timepoint,value \n")
    IO.write(file,"timepoint,")

    # Build and write out the header string
    list_of_timepoints = Enum.sort(Map.keys(timepoint_data))
    [ first | [ second | _ ]] = list_of_timepoints
    second_element_keys = Map.keys(Map.get(timepoint_data,second))
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
        acc <> Integer.to_string(field_value) <> ","

      end)
      IO.write(file,string <> " \n")
    end)

    File.close(file)
    IO.inspect(file_path)

    {:noreply,state}
  end


end