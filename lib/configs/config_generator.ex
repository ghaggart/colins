use Timex
require Logger
require Math

defmodule Colins.Configs.ConfigGenerator do


    def build_config_with_topology(sim_id,max_timepoint,_results_folder,network_topology,mesh_size,start_step_size \\ nil) do

      %{
        "sim_id" => sim_id,
        "max_timepoint" => max_timepoint,
        "node_type" => "particles",
        "mesh_size" => mesh_size,
        "network_topology" => network_topology

      }

    end

    def build_config(sim_id,max_timepoint,results_folder,network_topology_config_file,mesh_size,start_step_size \\ nil) do

       %{
          "sim_id" => sim_id,
          "results_folder" => results_folder,
          "max_timepoint" => max_timepoint,
          "node_type" => "particles",
          "mesh_size" => mesh_size,

          "network_topology" => read_network_topology_from_file(network_topology_config_file,start_step_size)

            }

    end

    def read_network_topology_from_sbml(filename,start_step_size) do

      Logger.info("\nReading SBML file...")

      #[ topology | _ ] = YamlElixir.read_all_from_string(Colins.Erlport.Helper.import_config_from_sbml(filename),atoms: true)
      topology = Colins.Erlport.PythonCmd.import_config_from_sbml(filename)
      sanitise_network_topology(topology,start_step_size)

    end

    def read_network_topology_from_yaml(filename,start_step_size) do

      Logger.info("\nReading network config file...")

      topology = YamlElixir.read_from_file(filename,atoms: true)
      sanitise_network_topology(topology,start_step_size)

    end

    def read_network_topology_from_file(filename,start_step_size) do

      case Path.extname(String.downcase(filename)) do

          a when (a == ".yml" or a == ".yaml") -> read_network_topology_from_yaml(filename,start_step_size)
          a when (a == ".sbml" or a == ".xml") -> read_network_topology_from_sbml(filename,start_step_size)
      end

    end

    def read_config_from_file(filename,start_step_size) do

        config = YamlElixir.read_from_file(filename,atoms: true)

        network_topology = sanitise_network_topology(Map.get(config,"network_topology"),start_step_size)

        Map.put(config,"network_topology",network_topology)

    end

    def sanitise_network_topology(network_topology,start_step_size) do

        #IO.inspect(network_topology)

        # Process the edge lambda inputs
        edges = Map.get(network_topology,"edges")
        processed_edges = Enum.reduce(edges,%{},fn({edge_id,edge_data},acc) ->

            lambda_str = Colins.Utilities.Math.convert_math_to_elixir(Map.get(edge_data,"lambda"))

            #IO.inspect(lambda_str)
            {lambda,_} = Code.eval_string(lambda_str)
            #IO.inspect(lambda)
            new_edge_data = Map.put(edge_data,"lambda",lambda)
            new_edge_data = Map.put(new_edge_data,"lambda_string",Map.get(edge_data,"lambda"))

            #new_input_map = sanitise_edge_input_map(Map.get(edge_data,"inputs"))

            #new_edge_data = Map.put(new_edge_data,"inputs",new_input_map)

            new_edge_data = Map.put(new_edge_data,"inputs",Map.get(edge_data,"inputs"))

            Map.put(acc,edge_id,new_edge_data)
        end)

        # Build the solver_ids for the partitions
        partitions = Map.get(network_topology,"partitions")
        processed_partitions = Enum.reduce(partitions,%{},fn({partition_id,partition_data},acc) ->

            partition_data = Map.put(partition_data,"solver_id",build_solver_id(Map.get(partition_data,"solver_type"),partition_id,Map.get(partition_data,"local_error_maximum")))

            partition_data = case start_step_size do

                nil -> partition_data
                _ -> Map.put(partition_data,"start_step_size",String.to_float(start_step_size))

            end
            Map.put(acc,partition_id,partition_data)

        end)

        network_topology = Map.put(network_topology,"partitions",processed_partitions)
        network_topology = Map.put(network_topology,"edges",processed_edges)

        network_topology
    end

    def build_solver_id(solver_type,partition_id,local_error_maximum) do

      String.to_atom(solver_type <> "_p" <> Integer.to_string(partition_id) <> "_e" <> String.replace(String.replace(Float.to_string(local_error_maximum), ".", "x"),"-","_"))

    end

    def sanitise_edge_input_map(input_map) do

        Enum.reduce(input_map,%{},fn({input_name,input_list},acc) ->

            input_tuple = Enum.reduce(input_list,{},fn(element,acc) ->
                Tuple.append(acc,element)
            end)
            Map.put(acc,input_name,input_tuple)
        end)

    end

    def get_test_network_topology() do

        %{  "nodes" => %{  :node_one  => %{"initial_value" => 100},
                                   :node_two => %{"initial_value" => 0},
                                   },

                  "edges" => %{:edge_one_decay_to_two => %{ "solver" => %{"solver_type"=>"Basic",
                                                                       "start_step_size" => 1.0},

                                                           "inputs" => %{"a" => {:get_value,:node_one}},


                                                         "lambda" => fn(a) -> (a * 0.3)  end,

                                                         "targets" => %{:node_one => "subtract",
                                                                           :node_two => "add"},
                                                       }}

                             #   :edge_PAPS_decay     => %{ "inputs" => %{ "a" => {:static_value,D.new(2.0)},
                              #                                          "b" => {:get_value,:node_PAPS}},

                            #                             "function" => fn(a,b) -> D.mult(a,b) end,

                           #                              "targets" => %{:node_PAPS => "subtract"},
                           #                             },





                 }
    end


end