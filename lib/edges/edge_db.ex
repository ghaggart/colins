defmodule Colins.Edges.EdgeDB do
    @moduledoc "Database of edge definitions"

    use GenServer

    def start_link() do

        GenServer.start_link(__MODULE__,[], [name: __MODULE__])
    end

    def init([]) do

        {:ok, %{}}

    end

    def setup(edge_definitions) do

       GenServer.cast(__MODULE__,{:setup,edge_definitions})

    end

    def handle_cast({:setup,edge_definitions},state) do

        {:noreply, Map.put(state,"edge_definitions",edge_definitions)}

    end

    def get_edge_definitions(edge_id_list) do

        GenServer.call(__MODULE__,{:get_edge_definitions,edge_id_list})

    end

    def handle_call({:get_edge_definitions,edge_id_list},_from,state) do

        {:reply,Map.take(Map.get(state,"edge_definitions"),edge_id_list),state}

    end


end
