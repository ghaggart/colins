require Logger

defmodule Colins.Solvers.RungeKuttaFehlberg do
  @moduledoc "

      Source:  http://maths.cnam.fr/IMG/pdf/RungeKuttaFehlbergProof.pdf

      dy/dt = whatevs

      k1 = h * f(tk,yk)

      k2 = h * f(tk + (1/4 * h),yk + (1/4 * k1))

      k3 = h * f(tk + (3/8 * h),yk + (3/32 * k1) + (9/32 * k2))

      k4 = h * f(tk + (12/13 * h),yk + (1932/2197 * k1) - (7200/2197 * k2) + (7296/2197 * k3))

      k5 = h * f(tk + h,yk + (439/216 * k1) - (8 * k2) + (3680/513 * k3) - (845/4104 * k4))

      k6 = h * f(tk + (1/2 * h), yk - (8/27 * k1) + (2 * k2) - (3544/2565 * k3) + (1859/4104 * k4) - (11/40*k5))

      Then an approximation to the solution of the I.V.P. is made using a Runge-Kutta method of order 4:

      yk+1 = yk + (25/216 * k1) + (1408/2565 * k3) + (2197/4101 * k4) - (1/5 * k5)

      A better value for the solution is determined using a Runge-Kutta method of order 5:

      zk+1 = yk + (16/35 * k1) + (6656/12825 * k3) + (28561/56430 * k4) - (9/50 * k5) + (2/55 * k6)

      The error estimate is the difference between these 2 values:

      error = zk+1 - yk+1

      The optimal step size sh can be determined by multiplying the scalar s times the current step size h. The scalar s is

      s = ( tol h / (2|zk+1 - yk+1))^1/4
      s ~ 0.84( tol h / (zk+1 - yk+1))^1/4

      where tol h is the error tolerance. Suggested value for this is 0.00002
    "

  # Check the output.

  @doc "Get the timestep solver function sequence. Keys map to function names. Executed sequentially."
  def get_solve_sequence() do

    [ :run_k1, :run_k2, :run_k3, :run_k4, :run_k5, :run_k6, :calculate_weighted_average_and_error ]

  end

  def run_k1(solver_id,edge_id,edge_definition,node_data,_step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k1 running")

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    #_output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
      Map.put(acc,input_name,Map.get(node_data,node_id))
    end)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    #IO.inspect(processed_inputs)
    #IO.inspect(Map.get(edge_definition,"lambda_string"))
    #IO.inspect(number_of_inputs)

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs)

    lambda_output = lambda_output * step_size

   # IO.inspect("k1")
   # IO.inspect(lambda_output)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k1: " <> inspect(lambda_output))

    returned_values = Map.put(%{},"k1",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_k2(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

   # output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
      # Parse the values for this:
      #k2 = h * f(tk + (1/4 * h),yk + (1/4 * k1))
      parsed_value = case node_id do

        :timepoint -> Float.round(Map.get(node_data,node_id) + (1/4 * step_size),11)
        _ ->  Map.get(node_data,node_id) + (1/4 * Map.get(step_calculated_data,"k1"))

      end
      Map.put(acc,input_name,parsed_value)

    end)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

  #  IO.inspect("k2")
  #  IO.inspect(lambda_output)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k2: " <> inspect(lambda_output))

    returned_values = Map.put(%{},"k2",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_k3(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

    # Get the value of k2 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

#      output_var= Colins.Solvers.Utils.get_output_var(outputs)

      number_of_inputs = length(Map.values(inputs))

      processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

        # Parse the values for this:
        #k3 = h * f(tk + (3/8 * h),yk + (3/32 * k1) + (9/32 * k2))
        parsed_value = case node_id do

          :timepoint -> Float.round(Map.get(node_data,node_id) + (3/8 * step_size),11)
          _ ->  Map.get(node_data,node_id) + (3/32 * Map.get(step_calculated_data,"k1")) + (9/32 * Map.get(step_calculated_data,"k2"))

        end
        Map.put(acc,input_name,parsed_value)

      end)

      Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

      # Call the lambda with the new data
      # k1 = h * dydx(x0, y)
      lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    #  IO.inspect("k3")
    #  IO.inspect(lambda_output)

      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k3: " <> inspect(lambda_output))

      returned_values = Map.put(%{},"k3",lambda_output)

      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_k4(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

#      output_var= Colins.Solvers.Utils.get_output_var(outputs)

      number_of_inputs = length(Map.values(inputs))

      processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

        # Parse the values for this:
        #k4 = h * f(tk + (12/13 * h),yk + (1932/2197 * k1) - (7200/2197 * k2) + (7296/2197 * k3))
        parsed_value = case node_id do

          :timepoint -> Map.get(node_data,node_id) + (12/13 * step_size)
          _ ->  Map.get(node_data,node_id) + (1932/2197 * Map.get(step_calculated_data,"k1")) - (7200/2197 * Map.get(step_calculated_data,"k2")) + (7296/2197 * Map.get(step_calculated_data,"k3"))

        end
        Map.put(acc,input_name,parsed_value)

      end)

      Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

      # Call the lambda with the new data
      # k1 = h * dydx(x0, y)
      lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    #  IO.inspect("k4")
    #  IO.inspect(lambda_output)

      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k4: " <> inspect(lambda_output))

      returned_values = Map.put(%{},"k4",lambda_output)

      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)
  end


  @doc "Calculate the h/2 values for error calculation"
  def run_k5(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

   #   output_var= Colins.Solvers.Utils.get_output_var(outputs)

      number_of_inputs = length(Map.values(inputs))

     # k5 = h * f(tk + h,yk + (439/216 * k1) - (8 * k2) + (3680/513 * k3) - (845/4104 * k4))

      processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

        # Parse the values for this:
        #k5 = h * f(tk + h,yk + (439/216 * k1) - (8 * k2) + (3680/513 * k3) - (845/4104 * k4))
        parsed_value = case node_id do

          :timepoint -> Float.round(Map.get(node_data,node_id) + step_size,11)
          _ ->  Map.get(node_data,node_id) + (439/216 * Map.get(step_calculated_data,"k1")) - (8 * Map.get(step_calculated_data,"k2")) + (3680/513 * Map.get(step_calculated_data,"k3")) - (845/4104 * Map.get(step_calculated_data,"k4"))

        end
        Map.put(acc,input_name,parsed_value)

      end)

      Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

      # Call the lambda with the new data
      # k1 = h * dydx(x0, y)
      lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

   #   IO.inspect("k5")
   #   IO.inspect(lambda_output)

      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k5: " <> inspect(lambda_output))

      returned_values = Map.put(%{},"k5",lambda_output)

      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end



  @doc "Calculate the h/2 values for error calculation"
  def run_k6(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,_timepoint,_mesh_size,_local_error_maximum) do

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

     # output_var= Colins.Solvers.Utils.get_output_var(outputs)

      number_of_inputs = length(Map.values(inputs))

      processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

        # Parse the values for this:
        #6 = h * f(tk + (1/2 * h), yk - (8/27 * k1) + (2 * k2) - (3544/2565 * k3) + (1859/4104 * k4) - (11/40*k5))
        parsed_value = case node_id do

          :timepoint -> Float.round(Map.get(node_data,node_id) + (0.5 * step_size),11)
          _ ->  Map.get(node_data,node_id) - (8/27 * Map.get(step_calculated_data,"k1")) + (2 * Map.get(step_calculated_data,"k2")) - (3544/2565 * Map.get(step_calculated_data,"k3")) + (1859/4104 * Map.get(step_calculated_data,"k4")) - (11/40 * Map.get(step_calculated_data,"k5"))

        end
        Map.put(acc,input_name,parsed_value)

      end)

      Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

      # Call the lambda with the new data
      # k1 = h * dydx(x0, y)
      lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    # IO.inspect("k6")
    #  IO.inspect(lambda_output)

      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k5: " <> inspect(lambda_output))

      returned_values = Map.put(%{},"k6",lambda_output)

      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

    end

  def calculate_weighted_average_and_error(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,local_error_maximum) do

      #local_error_maximum = 1.0e-12

      inputs = Map.get(edge_definition,"inputs")
      outputs = Map.get(edge_definition,"outputs")

      output_var= Colins.Solvers.Utils.get_output_var(outputs)

      previous_timepoint_value = Map.get(node_data,:timepoint)
      k1 = Map.get(step_calculated_data,"k1")
      k2 = Map.get(step_calculated_data,"k2")
      k3 = Map.get(step_calculated_data,"k3")
      k4 = Map.get(step_calculated_data,"k4")
      k5 = Map.get(step_calculated_data,"k5")
      k6 = Map.get(step_calculated_data,"k6")

      fifth_order_gradient = (25/216 * k1) + (1408/2565 * k3) + (2197/4101 * k4) - (1/5 * k5)
      sixth_order_gradient = (16/135 * k1) + (6656/12825 * k3) + (28561/56430 * k4) - (9/50 * k5) + (2/55 * k6)

      next_value_of_the_output = Map.get(node_data,output_var) + fifth_order_gradient

      fifth_order_value = Map.get(node_data,output_var) + fifth_order_gradient
      sixth_order_value = Map.get(node_data,output_var) + sixth_order_gradient

      error_estimate_modulus = Colins.Utilities.Math.sign_pos(sixth_order_value - fifth_order_value)

      error_estimate_div_step_size = error_estimate_modulus / step_size

      optimal_step_size = case error_estimate_modulus do

          0.0 -> step_size
          _ -> (Math.pow(0.84 * (local_error_maximum / error_estimate_div_step_size),1/4) * step_size)

      end

      returned_values = %{"error_estimate" => error_estimate_modulus, "optimal_step_size" => optimal_step_size}

      Logger.debug("\n current value of y: " <> inspect(previous_timepoint_value))
      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " fifth_order_gradient: " <> inspect(fifth_order_gradient))
      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " sixth_order_gradient: " <> inspect(sixth_order_gradient))
      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " error_estimate: " <> inspect(error_estimate_modulus))
      Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " optimal_step_size: " <> inspect(optimal_step_size))
      Logger.debug("\n next value of y: " <> inspect(next_value_of_the_output))

      Colins.Solvers.Utils.send_to_nodes(next_value_of_the_output,outputs,Float.round(timepoint + step_size,11))
      #Colins.Edges.EdgeData.commit_timepoint_data(edge_id,timepoint)
      Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values,:calculate_weighted_average_and_error)

  end

end