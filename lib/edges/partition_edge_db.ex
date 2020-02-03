defmodule Colins.Edges.PartitionEdgeDB do
  @moduledoc "Database of edge definitions for partitions"

  use GenServer

  def start_link() do

    GenServer.start_link(__MODULE__,[], [name: __MODULE__])
  end

  def init([]) do

    {:ok, %{}}

  end

  def setup(edges) do

    GenServer.cast(__MODULE__,{:setup,edges})

  end

  def handle_cast({:setup,edges},state) do

    {:noreply, Map.put(state,"partition_edges",edges)}

  end

  def get_edge_definitions(partition_id) do

    GenServer.call(__MODULE__,{:get_partition_edges,partition_id})

  end

  def handle_call({:get_partition_edges,partition_id},_from,state) do

    {:reply,Map.get(state,"partition_edges"),partition_id,state}

  end


end
