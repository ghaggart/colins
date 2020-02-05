defmodule Colins do
    @moduledoc """

    Command line script for Colins

    ## Examples

        > ./colins -n path/to/network_config_file -i sim_id -l sim_length

    """


    use Application

    @doc "Start the main supervisor"
    def start(_type, _args) do

        Colins.Supervisors.AppSupervisor.start_link()
    end

    @doc """

    Main method. Setups and starts the simulation.
    Checks if the sim_complete_file file exists. If so, exit.
    """
    def main(args) do

        #Colins.Supervisors.AppSupervisor.start_link()

        {opts,_,_}= OptionParser.parse(args,switches: [:network_topology_file,:sim_id,:sim_length,:results_folder,:mesh_size,:start_step_size],aliases: [n: :network_topology_file, i: :sim_id, f: :results_folder, l: :sim_length, m: :mesh_size, s: :start_step_size])

        opts = case opts[:start_step_size] do
            nil -> opts ++ [start_step_size: nil]
            _ -> opts
        end

        Colins.start(nil, nil)

        Colins.MainController.setup_simulation(Colins.Configs.ConfigGenerator.build_config(opts[:sim_id],String.to_integer(opts[:sim_length]),opts[:results_folder],opts[:network_topology_file],String.to_float(opts[:mesh_size]),opts[:start_step_size]))
        #Colins.MainController.setup_simulation(Colins.Configs.TestConfigs.build_config(String.to_integer(opts[:sim_id]),String.to_integer(opts[:sim_length])))

        Colins.Timesteps.AdaptiveMultiRateTimestepController.start_simulation()

        results_path = opts[:results_folder] <> "/" <> opts[:sim_id]

        sim_complete_file = Path.join([results_path,"sim_complete_file"])

        check_complete(sim_complete_file)

        System.halt(0)

    end

    @doc "Every 3 seconds, check if the sim_complete_file exists."
    def check_complete(sim_complete_file) do

        :timer.sleep(1000)

        case File.exists?(sim_complete_file) do

            true -> true
            false -> check_complete(sim_complete_file)

        end

    end

end