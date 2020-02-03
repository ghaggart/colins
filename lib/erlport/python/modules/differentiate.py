import sympy_functions
import sys
import yaml

# arg1 = expr_string
# arg2 = var_string

expr_string = sys.argv[1]
var_string = sys.argv[2]

print(yaml.dump(sympy_functions.differentiate_and_take_partial_derivatives(expr_string,var_string),width=float("inf")))