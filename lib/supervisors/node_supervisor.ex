defmodule Colins.Supervisors.NodeSupervisor do

    use Supervisor

    # Must implement start_link
    def start_link(config) do

        # Call the Supervisor method
        Supervisor.start_link(__MODULE__,config, name: __MODULE__)

    end

    def start_link() do

        # Call the Supervisor method
        Supervisor.start_link(__MODULE__,[], name: __MODULE__)

    end

    def init([]) do

        supervise([],strategy: :one_for_one)
    end

end