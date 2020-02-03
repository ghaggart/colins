require Logger

defmodule Colins.Solvers.RungeKutta4 do
  @moduledoc "

        # REWRITE 24/09/2019

        Solve systems of coupled ODEs using the RungeKutta4 method

        dy/dt = f(y,t)

        where yi = the dynamic variable y at interval i, and ti = the timepoint at interval i

        k1, k2, k3, and k4 are estimates of the gradient at different coordinates of the interval
        yi+1 is the weighted average of the gradient * the step_size h


        k1 = f(yi,ti)
        k2 = f(yi + (k1 * h/2),ti + h/2)
        k3 = f(yi + (k2 * h/2),ti + h/2)
        k4 = f(yi + (k3 * h),ti + h)

        yi+1 = 1/6(k1 + 2k2 + 2k3 + k4) * h


        # REWRITE 26/09/2019

        https://www.geeksforgeeks.org/runge-kutta-4th-order-method-solve-differential-equation/

        Given following inputs,

            An ordinary differential equation that defines value of dy/dx in the form x and y.
            Initial value of y, i.e., y(0)
            Thus we are given below.

        dx/dy = f(x,y), y(0) y0

        The task is to find value of unknown function y at a given point x.
        The Runge-Kutta method finds approximate value of y for a given x. Only first order ordinary differential equations can be solved by using the Runge Kutta 4th order method.
        Below is the formula used to compute next value yn+1 from previous value yn. The value of n are 0, 1, 2, 3, ….(x – x0)/h. Here h is step height and xn+1 = x0 + h
        Lower step size means more accuracy.

        k1 = h * f(xn,yn)
        k2 = h * f(xn + h/2,yn + k1/2)
        k3 = h * f(xn + h/2,yn + k2/2)
        k4 = h * f(xn + h,yn + k3)

        yn+1 = yn + k1/6 + k2/3 + k3/3 + k4/6 + O(h^5)

        The formula basically computes next value yn+1 using current yn plus weighted average of four increments.

        k1 is the increment based on the slope at the beginning of the interval, using y
        k2 is the increment based on the slope at the midpoint of the interval, using y + hk1/2.
        k3 is again the increment based on the slope at the midpoint, using using y + hk2/2.
        k4 is the increment based on the slope at the end of the interval, using y + hk3.
        The method is a fourth-order method, meaning that the local truncation error is on the order of O(h5), while the total accumulated error is order O(h4).

        Python version:

        # Python program to implement Runge Kutta method
        # A sample differential equation dy / dx = (x - y)/2
        def dydx(x, y):
          return ((x - y)/2)

        # Finds value of y for a given x using step size h
        # and initial value y0 at x0.
        def rungeKutta(x0, y0, x, h):
          # Count number of iterations using step size or
          # step height h
          n = (int)((x - x0)/h)
          # Iterate for number of iterations
          y = y0
          for i in range(1, n + 1):
            #Apply Runge Kutta Formulas to find next value of y
            k1 = h * dydx(x0, y)
            k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
            k3 = h * dydx(x0 + 0.5 * h, y + 0.5 * k2)
            k4 = h * dydx(x0 + h, y + k3)

            # Update next value of y
            y = y + (1.0 / 6.0)*(k1 + 2 * k2 + 2 * k3 + k4)

            # Update next value of x
            x0 = x0 + h
          return y

        # Driver method
        x0 = 0
        y = 1
        x = 2
        h = 0.2
        print 'The value of y at x is:', rungeKutta(x0, y, x, h)

        # This code is contributed by Prateek Bhindwar


    "

  # Check the output.

  @doc "Get the timestep solver function sequence. Keys map to function names. Executed sequentially."
  def get_solve_sequence() do

    [ :run_k1, :run_k2, :run_k3, :run_k4, :calculate_weighted_average ]

    # REWRITE 24/09/2019 - k2 = f(yi + (k1 * h/2),ti + h/2)
    #[ :run_k1, :run_k2, :run_k3, :run_k4, :calculate_weighted_average_and_error ]
  end
  # Run the output as normal
  def run_k1(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k1 running")

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    IO.inspect("k1 calc")
    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
        Map.put(acc,input_name,Map.get(node_data,node_id))
    end)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    IO.inspect(processed_inputs)

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    IO.inspect(processed_inputs)
    IO.inspect(lambda_output)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k1: " <> inspect(lambda_output))

    returned_values = Map.put(%{},"k1",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  # Run the lambda, replacing the input for the variable that is the output var
  def run_k2(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,_local_error_maximum) do

    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    IO.inspect("k2 calc")

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
        # Parse the values for this:
        #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)

        parsed_value = case node_id do

            :timepoint -> Float.round(Map.get(node_data,node_id) + (0.5 * step_size),11)
            _ ->  Map.get(node_data,node_id) + (0.5 * Map.get(step_calculated_data,"k1"))

        end
        Map.put(acc,input_name,parsed_value)

    end)

#    System.halt(0)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

        # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k2: " <> inspect(lambda_output))

    IO.inspect("k2 calc")
    IO.inspect(processed_inputs)
    IO.inspect(lambda_output)

    returned_values = Map.put(%{},"k2",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_k3(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,_local_error_maximum) do
    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

      # Parse the values for this:
      #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
      parsed_value = case node_id do

        :timepoint -> Float.round(Map.get(node_data,node_id) + (0.5 * step_size),11)
        _ ->  Map.get(node_data,node_id) + (0.5 * Map.get(step_calculated_data,"k2"))

      end
      Map.put(acc,input_name,parsed_value)

    end)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size


    IO.inspect("k3 calc")
    IO.inspect(processed_inputs)
    IO.inspect(lambda_output)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k3: " <> inspect(lambda_output))

    returned_values = Map.put(%{},"k3",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_k4(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k4 running")

    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->

      # Parse the values for this:
      #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
      parsed_value = case node_id do

        :timepoint -> Float.round(Map.get(node_data,node_id) + step_size,11)
        _ ->  Map.get(node_data,node_id) +  Map.get(step_calculated_data,"k3")

      end
      Map.put(acc,input_name,parsed_value)

    end)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k4: " <> inspect(lambda_output))

    IO.inspect("k4 calc")
    IO.inspect(processed_inputs)
    IO.inspect(lambda_output)

    returned_values = Map.put(%{},"k4",lambda_output)

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def calculate_weighted_average(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,mesh_size,local_error_maximum) do

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    weighted_average_gradient = (1/6) * (Map.get(step_calculated_data,"k1") + (2 * Map.get(step_calculated_data,"k2")) + (2 * Map.get(step_calculated_data,"k3")) + Map.get(step_calculated_data,"k4"))
    weighted_average_integral = weighted_average_gradient * step_size

    next_value_of_the_output = Map.get(node_data,output_var) + weighted_average_gradient

    IO.inspect("weighted average calc")
    IO.inspect(weighted_average_gradient)
    IO.inspect(weighted_average_integral)
    IO.inspect(next_value_of_the_output)

    returned_values = %{"weighted_average_gradient"=>weighted_average_gradient,"weighted_average_integral"=>weighted_average_integral}


    Logger.debug("\n current value of y: " <> inspect(Map.get(node_data,output_var)))
    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " weighted_average_gradient: " <> inspect(weighted_average_gradient))
    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " weighted_average_integral: " <> inspect(weighted_average_integral))
    Logger.debug("\n next value of y: " <> inspect(next_value_of_the_output))

    Colins.Solvers.Utils.send_to_nodes(next_value_of_the_output,outputs,Float.round(timepoint + step_size,11))

    Colins.Solvers.ExplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

end