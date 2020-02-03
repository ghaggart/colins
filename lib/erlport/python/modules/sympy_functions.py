from sympy import *

def convert_math_python_to_elixir(expr_string):

    return expr_string.replace("**","^")

# Take a string specifying the expression of the function to be differentiated and a string specifying the tuple of function variables (ie sympy symbols)
def differentiate_and_take_partial_derivatives(expr_string,var_string):

    #expr_string = expr_string.decode("utf-8")
    #var_string = var_string.decode("utf-8")
    vars = var_string.split(',')

    for var in vars:
        exec(var + " = symbols(\"" + var + "\")")

    exec("ldydx = lambdify((" + var_string + ")," + expr_string + ")")

    partial_derivative_functions = {}

    for var in vars:

        exec("partial_derivative_functions[var] = convert_math_python_to_elixir(str(diff(" + expr_string + ",var)))")

    return partial_derivative_functions




