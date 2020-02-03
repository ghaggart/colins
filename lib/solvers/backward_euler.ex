require Logger

defmodule Colins.Solvers.BackwardEuler do
  @moduledoc "

      Source:  https://www.astro.princeton.edu/~gk/A403/numinteg.pdf

          dy/dt = f(t,y)

          yk+1 = yk + f(tk+1,yk+1) * h

      Use the Newton-Raphson method to solve following equation for 0.

          F(yk+1,old) ~= yk+1 - yk - f(tk+1,yk+1) * h = 0

      Calculate the first estimate for yk+1, thereby finding it is not zero.

      Expand it in a Taylor series to obtain:

          F(yk+1,old) + (dF/dy)k+1,old   dy = 0,

      New, corrected value of yk+1 can be found using:

          yk+1,new = yk+1,old + dy = yk+1,old - F(yk+1,old)/(dF,dy)k+1,old

      where

          (dF/dy)k+1,old = 1 - (df,dy)k+1,old * h

      Continue intil the value of F(yk+1) converges to zero, or within the error threshold.

      Suggested value for this is 0.00002

      Requirements:

        The original function, dy/dt = f(t,y)
        The 1st differential of the function f with respect to y, df/dy

        An initial guess.

        A function for calculating the value, iteratively.

        An error threshold to stop the calculation at.

        A maximum number of iterations. If the term does not converge after this number of iterations, half the step size.

        An error estimate.

    "

  @doc "Get the timestep solver function sequence. Keys map to function names. Executed sequentially. These are executed at start of step"
  def get_solve_sequence() do

    [ {:once,:build_newton_raphson_edge_definitions}, {:linear,:run_first_estimate}, {:iterative,:run_newton_raphson} ]

  end

  @doc "Take all the partial derivatives and construct a new lambda"
  def build_dydfx(partial_derivative_map,inputs) do

    # DO NOT INCLUDE :timepoint VARS!

    #string = "fn(input1,input2) -> (input1 * 1/2) + (input2 * -1/2) end"
    dydfx_lambda_input_string = Enum.reduce(partial_derivative_map,"fn(",fn({variable_name,expression},acc) ->
      variable_name = to_string(variable_name)
      #case Map.get(inputs,variable_name) do
      #  _ -> acc <> variable_name <> ","
      #end
      acc <> variable_name <> ","
    end)
    dydfx_lambda_expr_string = Enum.reduce(partial_derivative_map,"",fn({variable_name,expression},acc) ->

      variable_name = to_string(variable_name)

      case Map.get(inputs,variable_name) do
        :timepoint ->  acc
        _ -> acc <> "(" <> variable_name <> " * " <> to_string(expression) <> ") + "
      end


    end)
    #string = "fn(input1,input2) -> (input1 * 1/2) + (input2 * -1/2) end"
    dydfx_lambda_input_string = String.trim_trailing(dydfx_lambda_input_string,",") <> ") -> "
    dydfx_lambda_expr_string = String.trim_trailing(dydfx_lambda_expr_string," + ") <> " end"
    dydfx_lambda_input_string <> dydfx_lambda_expr_string

  end

  def build_newton_raphson_edge_definitions(solver_id,edge_id,edge_definition) do

    inputs = Map.get(edge_definition,"inputs")
  #  IO.inspect(inputs)
    outputs = Map.get(edge_definition,"outputs")
    lambda = Map.get(edge_definition,"lambda")
    lambda_string = Map.get(edge_definition,"lambda_string")

    [ lhs | [ rhs | _ ] ] = String.split(lambda_string," -> ")
    lhs = String.replace(lhs,"fn(","")
    var_string = String.trim(String.replace(lhs,")",""))
    expr_string = String.trim(String.replace(rhs,"end",""))

    # Get the partial derivatives
    pdfs = Colins.Erlport.PythonCmd.differentiate(expr_string,var_string)

    partial_derivative_lambda_string = build_dydfx(pdfs,inputs)

    {partial_derivative_lambda,_} = Code.eval_string(partial_derivative_lambda_string)

    # We use these partial derivatives to construct the partial_derivative_lambda - a linear product of all the partial derivatives.
    # Ie (input1 - input2)/2 becomes (input1 * 1/2) + (input2 * -1/2)
    #%{'input1' => '1/2', 'input2' => '-1/2'}

    returned_values = %{"partial_derivative_lambda_string"=>partial_derivative_lambda_string,"partial_derivative_lambda"=>partial_derivative_lambda}
    Colins.Solvers.ImplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values,:build_newton_raphson_edge_definitions)

  end


  def run_first_estimate(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,_mesh_size,_local_error_maximum) do

    #IO.inspect(Atom.to_string(solver_id) <> " k1 running")

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
      parsed_value = case node_id do
        :timepoint -> Map.get(node_data,node_id)
        _ ->  Map.get(node_data,node_id)
      end
      Map.put(acc,input_name,parsed_value)
    end)

    #IO.inspect("here")
    #IO.inspect(processed_inputs)

    Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))

    # Call the lambda with the new data
    # k1 = h * dydx(x0, y)
    #lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size

   # IO.inspect("ldydx(new_x, new_y)")
    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size
#
    #IO.inspect(lambda_output)

   # IO.inspect("ldydx(new_x, new_y) * h")
   # IO.inspect(lambda_output * step_size)

  #  lambda_output = lambda_output * step_size

    Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " first estimate: " <> inspect(lambda_output))

    first_estimate = Map.get(node_data,output_var) + lambda_output

    returned_values = %{"previous_estimate"=>first_estimate}

    Colins.Solvers.ImplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values)

  end

  def run_newton_raphson(solver_id,edge_id,edge_definition,node_data,step_calculated_data,step_size,timepoint,newton_raphson_edge_definition) do

    # 1. Calculate the new estimate using the partial derivative functions
    # 2. Use this value to calculate the result of big_F (ie how close to zero it is)

    # Python version for ref
    #ldydx = differential equation
    #ldydf = partial derivative of ldydx
    #big_F = lambda previous_estimate,previous_y,x,h : previous_estimate - previous_y - ldydx((x+h),previous_y) * h
    # big_F = value_of_f from step before:
    #new_estimate = previous_estimate - (big_F(previous_estimate,previous_y,x,h)/(1-(ldfdy(previous_y) * h)))
    #value_of_F = big_F(new_estimate,previous_y,x,h)

   # IO.inspect("here")
   # IO.inspect(step_calculated_data)
   # IO.inspect(newton_raphson_edge_definition)
   # IO.inspect(edge_definition)
   # IO.inspect(node_data)

    #1. Calculate the first estimate - done in the previous step.
    #2. Calculate the new estimate using:

    inputs = Map.get(edge_definition,"inputs")
    outputs = Map.get(edge_definition,"outputs")

    output_var= Colins.Solvers.Utils.get_output_var(outputs)

    number_of_inputs = length(Map.values(inputs))

    previous_y = Map.get(node_data,output_var)
    previous_estimate = Map.get(step_calculated_data,"previous_estimate")

    processed_inputs = Enum.reduce(inputs,%{},fn({input_name,node_id},acc) ->
      parsed_value = case node_id do
        :timepoint -> Map.get(node_data,node_id) + step_size
        _ ->  Map.get(node_data,node_id)
      end
      Map.put(acc,input_name,parsed_value)
    end)

    lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs)

    previous_value_of_F = previous_estimate - previous_y - lambda_output * step_size

    #IO.inspect("previous_value_of_F")
    #IO.inspect(previous_value_of_F)

   # IO.inspect("previous_estimate")
   # IO.inspect(previous_estimate)

   # IO.inspect("previous_y")
   # IO.inspect(previous_y)

   # IO.inspect("ldydx_result")
   # IO.inspect(lambda_output)

   # IO.inspect("previous_estimate")
   # IO.inspect(previous_estimate)

   # IO.inspect("big_f")
   # IO.inspect(previous_value_of_F)

  #  IO.inspect("previous_y")
  #  IO.inspect(previous_y)


    # 1.
    # new_estimate = previous_estimate - (big_F(previous_estimate,previous_y,x,h)/(1-(ldfdy(previous_y) * h)))
    # big_F = value_of_f from step before:

    # sum ldfdy is the sum of all the partial derivative equations

    #partial_derivative_lambda = Map.get(step_calculated_data,"partial_derivative_lambda")

 #   IO.inspect("newton_raphson_edge_definition")
   # IO.inspect(newton_raphson_edge_definition)

    sum_ldfdy = Colins.Solvers.Utils.call_lambda(Map.get(newton_raphson_edge_definition,"partial_derivative_lambda"),number_of_inputs,processed_inputs)
    #new_estimate = previous_estimate - (previous_value_of_F / 1 - (sum_ldfdy  * step_size ))

  #  IO.inspect("ldfdy_result")
   # IO.inspect(sum_ldfdy)

   # IO.inspect("one_minus_ldfdy_h")
   # IO.inspect(1 - (sum_ldfdy  * step_size ))
#
    new_estimate = previous_estimate - (previous_value_of_F / (1 - (sum_ldfdy  * step_size )))

    #new_estimate = previous_estimate - (lambda_output / ((1 - sum_ldfdy)  * step_size ))
    #lambda_output

  #  IO.inspect("new_estimate")
   # IO.inspect(new_estimate)


    # 2. Use this value to calculate the result of big_F (ie how close to zero it is)

    #Logger.debug("\n Processed inputs: " <> inspect(processed_inputs))
    # Call the lambda with the new data
    # big_F = previous_estimate - previous_y - ldydx((new_x+h),previous_y) * h
    #lambda_output = Colins.Solvers.Utils.call_lambda(Map.get(edge_definition,"lambda"),number_of_inputs,processed_inputs) * step_size
    new_value_of_F = new_estimate - previous_y - lambda_output * step_size

   # IO.inspect("new_value_of_F")
  #  IO.inspect(new_value_of_F)

    #Logger.debug("\n" <> inspect(Map.get(edge_definition,"lambda_string")) <> " this estimate: " <> inspect(this_estimate))

    returned_values = %{"previous_estimate"=>new_estimate,
                        "value_of_F"=>new_value_of_F}

    returned_values = case {previous_estimate,new_estimate} do

      {a,b} when a == b -> Map.put(returned_values,"result_has_converged",:true)
        _ -> returned_values

    end

    Colins.Solvers.ImplicitSolverServer.notify_edge_complete(solver_id,edge_id,returned_values,:run_newton_raphson)

  end

end