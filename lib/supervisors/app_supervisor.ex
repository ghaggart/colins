defmodule Colins.Supervisors.AppSupervisor do

    use Supervisor

    # Must implement start_link
    def start_link() do

        # Call the Supervisor method
        Supervisor.start_link(__MODULE__,[], name: __MODULE__)

    end

    # Init is called
    def init([]) do

        # Children to be supervised!
        children = [

            worker(Colins.MainController, []),
            supervisor(Colins.Supervisors.NodeSupervisor, []),
            supervisor(Colins.Supervisors.SimulationSupervisor, []),
        ]

        supervise(children,strategy: :one_for_one)

    end


end