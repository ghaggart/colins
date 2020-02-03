require Logger

defmodule Colins.Solvers.RungeKutta4Old do
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

  def get_output_var(outputs) do


   # IO.inspect(outputs)
    List.first(Map.keys(outputs))

  end

  def call_lambda(lambda,number_of_inputs,processed_inputs,step_size) do

      Colins.Solvers.Utils.call_lambda(lambda,number_of_inputs,processed_inputs) * step_size

  end

  # Run the output as normal
  def run_k1(solver_id,edge_id,edge_definition,step_size,timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k1 running")

    inputs = Map.get(edge_definition,"inputs")
    lambda = Map.get(edge_definition,"lambda")
    outputs = Map.get(edge_definition,"outputs")

    output_var= get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    #IO.inspect("inputs")
    #IO.inspect(inputs)

    processed_inputs = Colins.Solvers.Utils.process_input(inputs,timepoint,edge_id,step_size)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    #IO.inspect("Processed_args: ")
    #IO.inspect(processed_args)

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    lambda_output = call_lambda(lambda,number_of_inputs,processed_inputs,step_size)

    #Colins.Edges.EdgeData.set_scratchpad_var(edge_id,"k1",lambda_output)

    Colins.Nodes.MasterNode.set_scratchpad_var(output_var,solver_id,"k1",lambda_output)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k1: " <> inspect(lambda_output))

    Colins.Solvers.SolverServer.notify_edge_complete(solver_id,edge_id)

  end

  # Run the lambda, replacing the input for the variable that is the output var
  def run_k2(solver_id,edge_id,edge_definition,step_size,timepoint,_mesh_size,_local_error_maximum) do

    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    inputs = Map.get(edge_definition,"inputs")
    lambda = Map.get(edge_definition,"lambda")
    outputs = Map.get(edge_definition,"outputs")

    number_of_inputs = length(Map.values(inputs))

    output_var = get_output_var(outputs)

    #inputs = Colins.Solvers.Utils.convert_node_input_types_to_edge_data_scratchpad_vars(inputs,edge_id,__MODULE__,"k2")

    inputs = Colins.Solvers.Utils.convert_node_input_types_to_subfunction_input_types(inputs,solver_id,["k1"],__MODULE__,"k2")

    #IO.inspect(inputs)

    #IO.inspect(inputs)

    processed_inputs = Colins.Solvers.Utils.process_input(inputs,timepoint,edge_id,step_size)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    # Call the lambda with the new data
    # k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
    lambda_output = call_lambda(lambda,number_of_inputs,processed_inputs,step_size)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k2: " <> inspect(lambda_output))

    #Colins.Edges.EdgeData.set_scratchpad_var(edge_id,"k2",lambda_output)
    Colins.Nodes.MasterNode.set_scratchpad_var(output_var,solver_id,"k2",lambda_output)

    Colins.Solvers.SolverServer.notify_edge_complete(solver_id,edge_id)
  end


  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k2_input_variable(node_data,step_size) do

    #IO.inspect(node_data)

    #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
    # this bit -> y + 0.5 * k1
    Map.get(node_data,"timepoint_value") + (0.5 * Map.get(node_data,"k1"))

  end

  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k2_timepoint(timepoint,step_size) do

    #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
    # this bit -> x0 + 0.5 * h
    #IO.inspect(timepoint)
    #IO.inspect(step_size)
    Float.round(timepoint + (0.5 * step_size),11)

  end

  def run_k3(solver_id,edge_id,edge_definition,step_size,timepoint,_mesh_size,_local_error_maximum) do

    # Get the value of k1 and the node timepoint data,
    # Add the node timepoint data and k1 together before running the function
    # As per the algorithm above

    #IO.inspect(Atom.to_string(solver_id) <> " k3 running")

    inputs = Map.get(edge_definition,"inputs")
    lambda = Map.get(edge_definition,"lambda")
    outputs = Map.get(edge_definition,"outputs")

    # Add k1 to the input vars during node data extraction
    #inputs = Colins.Solvers.Utils.convert_node_input_types_to_subfunction_input_types(inputs,solver_id,["k2"])

    number_of_inputs = length(Map.values(inputs))

    output_var = get_output_var(outputs)

    #inputs = Colins.Solvers.Utils.convert_node_input_types_to_edge_data_scratchpad_vars(inputs,edge_id,__MODULE__,"k3")

    inputs = Colins.Solvers.Utils.convert_node_input_types_to_subfunction_input_types(inputs,solver_id,["k1","k2"],__MODULE__,"k3")

    processed_inputs = Colins.Solvers.Utils.process_input(inputs,timepoint,edge_id,step_size)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    lambda_output = call_lambda(lambda,number_of_inputs,processed_inputs,step_size)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k3: " <> inspect(lambda_output))

    #Colins.Edges.EdgeData.set_scratchpad_var(edge_id,"k3",lambda_output)
    Colins.Nodes.MasterNode.set_scratchpad_var(output_var,solver_id,"k3",lambda_output)

    Colins.Solvers.SolverServer.notify_edge_complete(solver_id,edge_id)
  end

  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k3_timepoint(timepoint,step_size) do

      #k2 = h * dydx(x0 + 0.5 * h, y + 0.5 * k1)
      # this bit -> x0 + 0.5 * h
      Float.round(timepoint + (0.5 * step_size),11)

  end

  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k3_input_variable(node_data,step_size) do


    #k3 = h * dydx(x0 + 0.5 * h, y + 0.5 * k2)
    # this bit -> y + 0.5 * k2
    Map.get(node_data,"timepoint_value") + (0.5 * Map.get(node_data,"k2"))

  end

  def run_k4(solver_id,edge_id,edge_definition,step_size,timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k4 running")

    inputs = Map.get(edge_definition,"inputs")
    lambda = Map.get(edge_definition,"lambda")
    outputs = Map.get(edge_definition,"outputs")


    number_of_inputs = length(Map.values(inputs))

    output_var = get_output_var(outputs)

    #inputs = Colins.Solvers.Utils.convert_node_input_types_to_edge_data_scratchpad_vars(inputs,edge_id,__MODULE__,"k4")

    #processed_inputs = Colins.Solvers.Utils.process_input(inputs,timepoint,edge_id,["k1","k2","k3"],step_size)

    inputs = Colins.Solvers.Utils.convert_node_input_types_to_subfunction_input_types(inputs,solver_id,["k1","k2","k3"],__MODULE__,"k4")

    processed_inputs = Colins.Solvers.Utils.process_input(inputs,timepoint,edge_id,step_size)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    lambda_output = call_lambda(lambda,number_of_inputs,processed_inputs,step_size)

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " k4: " <> inspect(lambda_output))

    # REWRITE 24/09/2019 - k3 = f(yi + (k2 * h/2),ti + h/2)
    #send_scratchpad_data_to_nodes(inputs,solver_id,"k4",lambda_output)
    #Colins.Edges.EdgeData.set_scratchpad_var(edge_id,"k4",lambda_output)
    Colins.Nodes.MasterNode.set_scratchpad_var(output_var,solver_id,"k4",lambda_output)
    Colins.Solvers.SolverServer.notify_edge_complete(solver_id,edge_id)

  end

  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k4_timepoint(timepoint,step_size) do

      #k2 = h * dydx(x0 + h, y + k3)
      # this bit -> 0 + h
      Float.round(timepoint + step_size,11)

    end

  @doc "Parse the output of the get_subfunction_data data type request"
  def parse_k4_input_variable(node_data,step_size) do


    #k4 = h * dydx(x0 + h, y + k3)
    # this bit ->  y + k3
    Map.get(node_data,"timepoint_value") + Map.get(node_data,"k3")

  end

  def calculate_weighted_average(solver_id,edge_id,edge_definition,step_size,timepoint,mesh_size,local_error_maximum) do

    #local_error_maximum = 0.01

    Logger.debug("\nError threshold: " <> inspect(local_error_maximum))

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var = get_output_var(outputs)

    #  IO.inspect(output_var)

    scratchpad_vars = Colins.Nodes.MasterNode.get_timepoint_data_and_multiple_subfunction_values(output_var,(timepoint - step_size),solver_id,["k1","k2","k3","k4"])
    #scratchpad_vars = Colins.Edges.EdgeData.get_scratchpad_vars(edge_id,["timepoint_value","k1","k2","k3","k4"])

    #  IO.inspect(scratchpad_vars)

    k1 = Map.get(scratchpad_vars,"k1")
    k2 = Map.get(scratchpad_vars,"k2")
    k3 = Map.get(scratchpad_vars,"k3")
    k4 = Map.get(scratchpad_vars,"k4")
    previous_timepoint_value =  Map.get(scratchpad_vars,"timepoint_value")

    #IO.inspect(previous_timepoint_value)

    #yi+1 = 1/6(k1 + 2k2 + 2k3 + k4) * h
    weighted_average_gradient = (1/6) * (k1 + (2 * k2) + (2 * k3) + k4)
    weighted_average_integral = weighted_average_gradient * step_size

    #next_value_of_the_output = Float.round(timepoint_value + weighted_average_integral,11)

    next_value_of_the_output = previous_timepoint_value + weighted_average_gradient

    Logger.debug("\n current value of y: " <> inspect(previous_timepoint_value))
    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " weighted_average_gradient: " <> inspect(weighted_average_gradient))
    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " weighted_average_integral: " <> inspect(weighted_average_integral))
    Logger.debug("\n next value of y: " <> inspect(next_value_of_the_output))

    Colins.Solvers.Utils.send_to_nodes(next_value_of_the_output,outputs,timepoint)

    Colins.Nodes.MasterNode.set_scratchpad_var(output_var,solver_id,"weighted_average_gradient",weighted_average_gradient)
    #Colins.Edges.EdgeData.set_scratchpad_vars(edge_id,%{"weighted_average_gradient" => weighted_average_gradient})
    Colins.Edges.EdgeData.commit_timepoint_data(edge_id,timepoint)
    Colins.Solvers.SolverServer.notify_edge_complete(solver_id,edge_id)

  end

end