import sbml_convert
import sys
import yaml

# arg1 = expr_string
# arg2 = var_string

sbml_filename = sys.argv[1]

print(yaml.dump(sbml_convert.import_from_sbml(sbml_filename),width=float("inf")))