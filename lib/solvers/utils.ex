require Logger

defmodule Colins.Solvers.Utils do

    @doc "Input map, timepoint, and module_parse_function. Module parse function is a tuple of module_name,function atom, and input list"
    def process_input(inputs,timepoint,edge_id,step_size) do

        acc_default = %{"processed_inputs"=>%{},"subfunction_cache"=>%{}}

        processed_inputs_and_cache = Enum.reduce(inputs,acc_default,fn({input_name,input_definition},acc) ->

            subfunction_cache = Map.get(acc,"subfunction_cache")

            {edited_input_definition,new_subfunction_cache} = parse_input(input_definition,timepoint,subfunction_cache,edge_id,step_size)

            Logger.debug("\n t:" <> inspect(timepoint) <> " i:" <> inspect(input_name) <> " v:" <> inspect(edited_input_definition))


            processed_inputs = Map.get(acc,"processed_inputs")
            processed_inputs = Map.put(processed_inputs,input_name,edited_input_definition)
            acc = Map.put(acc, "processed_inputs", processed_inputs)
            acc = Map.put(acc,"subfunction_cache",new_subfunction_cache)

        end)

        Map.get(processed_inputs_and_cache,"processed_inputs")

    end

    # Specific kind of node where the data contained is the timepoint - used for scratchpad vars.
    def parse_input({:dynamic,:timepoint},timepoint,subfunction_cache,_edge_id,_step_size) do

      {timepoint,subfunction_cache}

    end

    # Get the previous timepoint data
    def parse_input({:dynamic,node_id},timepoint,subfunction_cache,edge_id,step_size) do

        #value = Colins.Nodes.MasterNode.get_timepoint_data(node_id,(timepoint - step_size))

      # Colins.Nodes.MasterNode.get_timepoint_data(node_id,(timepoint - step_size))

      {data,subfunction_cache} = case Map.has_key?(subfunction_cache,node_id) do
          
            true -> {Map.get(subfunction_cache,node_id),subfunction_cache}
            false -> data = Colins.Nodes.MasterNode.get_timepoint_data(node_id,(timepoint - step_size))
                     {data,Map.put(subfunction_cache,node_id,data)}
        end


    end

    def parse_input({:constant,number},timepoint,subfunction_cache,_edge_id,_step_size) do

      {number,subfunction_cache}

    end

    def parse_input({:get_edge_data,:timepoint,variable_names,module,parse_function},timepoint,subfunction_cache,_edge_id,step_size) do

        # Call the data parser function. Ie, calculate y + k1/2
      {apply(module,parse_function,[ timepoint, step_size ]),subfunction_cache}

    end

    def parse_input({:get_edge_data,edge_id,variable_names,module,parse_function},_timepoint,subfunction_cache,edge_id,step_size) do

      #data = Colins.Edges.EdgeData.get_scratchpad_vars(edge_id,variable_names)

      # Call the data parser function. Ie, calculate y + k1/2
      #apply(module,parse_function,[ data , step_size ])

      {data,subfunction_cache} = case Map.has_key?(subfunction_cache,edge_id) do

        true -> {Map.get(subfunction_cache,edge_id),subfunction_cache}
        false -> data = Colins.Edges.EdgeData.get_scratchpad_vars(edge_id,variable_names)
                 {data,Map.put(subfunction_cache,edge_id,data)}
      end

      {apply(module,parse_function,[ data , step_size ]),subfunction_cache}

    end

    def parse_input({:get_subfunction_data,:timepoint,module,parse_function},timepoint,subfunction_cache,edge_id,step_size) do

      # Get the subfunction scratchpad and previous timepoint value
      #IO.inspect(module_parse_function)
      # Call the data parser function. Ie, calculate y + k1/2
      #apply(module,parse_function,[ timepoint , step_size ])
      {apply(module,parse_function,[ timepoint , step_size ]),subfunction_cache}

    end

    def parse_input({:get_subfunction_data,node_id,solver_id,variable_names,module,parse_function},timepoint,subfunction_cache,edge_id,step_size) do

      # Get the subfunction scratchpad and previous timepoint value
      #data = Colins.Nodes.MasterNode.get_timepoint_data_and_multiple_subfunction_values(node_id,(timepoint - step_size),solver_id,variable_names)

      # Call the data parser function. Ie, calculate y + k1/2
      #apply(module,parse_function,[ data , step_size ])

      {data,subfunction_cache} = case Map.has_key?(subfunction_cache,node_id) do

        true -> {Map.get(subfunction_cache,node_id),subfunction_cache}
        false -> data = Colins.Nodes.MasterNode.get_timepoint_data_and_multiple_subfunction_values(node_id,(timepoint - step_size),solver_id,variable_names)
                 {data,Map.put(subfunction_cache,node_id,data)}
      end

      {apply(module,parse_function,[ data , step_size ]),subfunction_cache}


    end

    def call_lambda(lambda,number_of_inputs,processed_inputs) do

        #input_list = Enum.reduce(processed_inputs,[],fn({input_id,input_val},acc) ->
        #    [ Float.to_string(input_val) | acc ]
        #end)
        #Enum.join(input_list,",")

        # Handles up to 20 inputs
        case number_of_inputs do

           0 -> lambda.()
           1 -> lambda.(Map.get(processed_inputs,"input1"))
           2 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"))
           3 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"))
           4 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"))
           5 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"))
           6 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"))
           7 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"))
           8 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"))
           9 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"))
           10 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"))
           11 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"))
           12 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"))
           13 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"))
           14 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"))
           15 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"))
           16 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"),Map.get(processed_inputs,"input16"))
           17 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"),Map.get(processed_inputs,"input16"),Map.get(processed_inputs,"input17"))
           18 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"),Map.get(processed_inputs,"input16"),Map.get(processed_inputs,"input17"),Map.get(processed_inputs,"input18"))
           19 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"),Map.get(processed_inputs,"input16"),Map.get(processed_inputs,"input17"),Map.get(processed_inputs,"input18"),Map.get(processed_inputs,"input19"))
           20 -> lambda.(Map.get(processed_inputs,"input1"),Map.get(processed_inputs,"input2"),Map.get(processed_inputs,"input3"),Map.get(processed_inputs,"input4"),Map.get(processed_inputs,"input5"),Map.get(processed_inputs,"input6"),Map.get(processed_inputs,"input7"),Map.get(processed_inputs,"input8"),Map.get(processed_inputs,"input9"),Map.get(processed_inputs,"input10"),Map.get(processed_inputs,"input11"),Map.get(processed_inputs,"input12"),Map.get(processed_inputs,"input13"),Map.get(processed_inputs,"input14"),Map.get(processed_inputs,"input15"),Map.get(processed_inputs,"input16"),Map.get(processed_inputs,"input17"),Map.get(processed_inputs,"input18"),Map.get(processed_inputs,"input19"),Map.get(processed_inputs,"input20"))

        end

    end

    def send_to_nodes(lambda_output,output_nodes,timepoint) do

        # once function output calculated, send to the tinputets
        Enum.map(output_nodes,fn({output_node,method}) ->

            ##IO.inspect(tinputet_bucket)
            ##IO.inspect(k1)

            case method do

                #"add" -> Colins.Nodes.Node.increment_value(tinputet_bucket,k1)

                #"subtract" -> Colins.Nodes.Node.increment_value(tinputet_bucket,-k1)

                "add" -> Colins.Nodes.MasterNode.increment_timepoint_value(output_node,timepoint,lambda_output)
                "subtract" -> Colins.Nodes.MasterNode.increment_timepoint_value(output_node,timepoint,-lambda_output)

#                _ -> Logger.info("mdl: Error - Unknown tinputet method " <> method <> " : "<> Map.get(state,"edge_id"))

            end

        end)

    end

    def get_output_parse_function(ki) do

        String.to_atom("parse_" <> ki <> "_input_variable")

    end


    def get_timepoint_parse_function(ki) do

      String.to_atom("parse_" <> ki <> "_timepoint")

    end

    @doc "Converts node input types to edge data scratchpad vars - for mapping ki module parse functions"
    def convert_node_input_types_to_edge_data_scratchpad_vars(inputs,output_var,edge_id,variable_names,module,ki) do

       Enum.reduce(inputs,%{},fn({input_name,{input_type,input_var}},acc) ->

          edited_input_definition = case {input_var,output_var} do

             {a,b} when (a == b) -> {:get_edge_data,edge_id,variable_names,module,get_output_parse_function(ki)}
             {a,b} when (a == :timepoint) -> {:get_edge_data,:timepoint,variable_names,module,get_timepoint_parse_function(ki)}
             _ -> {input_type,input_var}

          end

          Map.put(acc,input_name,edited_input_definition)

       end)

    end


    #TODO: Edit for versions with multiple scratchpad vars
    @doc "Converts the get_timepoint_data datatype to one which returns the necessary scratchpad vars as well"
    def convert_node_input_types_to_subfunction_input_types(inputs,solver_id,variable_names,module,ki) do

        Logger.debug("\nVariable names: " <> inspect(variable_names))

        # Process the input and convert the {:get_value,node_id} entries to the {:get_subfunction_data} entries
        Enum.reduce(inputs,%{},fn({input_name,input_definition},acc) ->

            new_input_type = case input_definition do

              # If input_definition == {:dynamic,:timepoint}
              {input_type,node_id} when (node_id == :timepoint) -> {:get_subfunction_data,:timepoint,module,get_timepoint_parse_function(ki)}
              # If input_definition == {:dynamic,node_id}
              {input_type,node_id} when (input_type == :dynamic) -> {:get_subfunction_data,node_id,solver_id,variable_names,module,get_output_parse_function(ki)}
              # Else
                _ -> input_definition

            end

            Map.put(acc,input_name,new_input_type)
        end)


    end


    def check_local_error_maximum(error_estimate,local_error_maximum) do

        case {error_estimate,local_error_maximum} do

            {error_estimate,local_error_maximum} when (error_estimate >= local_error_maximum) -> true

            {_,_} -> false

        end

        false


    end

    def build_stepper_id_for_new_step_size(stepper_id,step_size) do

        # Explode on edge_id _
        # 1st element is atom name + solver type
        # 2nd element is integer
        # 3rd element is decimal

        #element_list = String.split(edge_id,"_")

        #[ atom_name | [ integer_val | [ decimal_val | _ ] ] ] = String.split(Atom.to_string(stepper_id),"_")

        [ solver_type | [ old_integer_val | [ old_decimal_val | _ ] ] ] = String.split(Atom.to_string(stepper_id),"_")

#        IO.inspect("here")

#        IO.inspect(atom_name)
        #IO.inspect(integer_val)
        #IO.inspect(decimal_val)

        #old_step_size = String.to_float(integer_val <> "." <> decimal_val)

       # IO.inspect(old_step_size)

        [ integer_val | [ decimal_val | _ ] ] = String.split(Float.to_string(Float.round(step_size,11)),".")

#        IO.inspect(integer_val)
#        IO.inspect(decimal_val)

        new_stepper_id = String.to_atom(solver_type <> "_" <> integer_val <> "_" <> decimal_val)

#        IO.inspect(new_stepper_id)

        new_map = Map.put(%{}, "stepper_id", new_stepper_id)
        new_map = Map.put(new_map,"solver_type",solver_type)
        new_map = Map.put(new_map, "rounded_step_size", String.to_float(integer_val <> "." <> decimal_val))
        new_map = Map.put(new_map, "old_step_size", String.to_float(old_integer_val <> "." <> old_decimal_val))

#        IO.inspect(new_map)
    end

    def parse_inputs_to_send_to_scratchpad({:dynamic,node_name}) do

        {:dynamic,node_name}

    end

    def parse_inputs_to_send_to_scratchpad({:get_subfunction_data,node_name,_solver_name,_input_list}) do

        {:dynamic,node_name}

    end

    def parse_inputs_to_send_to_scratchpad({:constant,_value}) do

        {:constant,nil}

    end

    def get_output_var(outputs) do


      # IO.inspect(outputs)
      List.first(Map.keys(outputs))

    end

    def get_explicit_solver_list() do

      ["Euler","RungeKutta4","RungeKuttaFehlberg"]

    end

    def get_implicit_solver_list() do

      ["BackwardEuler","BackwardTrapezoid"]

    end


end