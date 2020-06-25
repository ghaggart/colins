from libsbml import *
import re

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

def get_edge_specie_name(specie_name):
    return "pv_" + specie_name

def get_node_specie_name(specie_name):
    return specie_name

# Loops over the entities and replaces functions with their values
def replace_function_inputs(string):

    operators = ['*','/',"+","-","=","(",")"]

    string_split = string.split(' ')

    new_string = ''

    input_count = 1
    for entity in string_split:

        if input_count == 1:
            separator = ""
        else:
            seperator = ","

        if entity in operators:
            new_string = new_string + entity
        else:
            new_string = new_string + separator + "input" + str(input_count)
            input_count = input_count + 1


    return new_string


def strip_function_inputs(string):

    splitter = string.split('(')

    return splitter[0]

def return_function_inputs(string):

    splitter = string.split('(')
    splitter2 = splitter[1].strip(')')

    return splitter2


def find_entity_type(string,species_ids,defined_parameters,compartment_sizes):

    if string in compartment_sizes.keys():
        return 'compartment'

    elif string in species_ids:
        return 'species'

    elif string in defined_parameters.keys():
        return 'parameter'

    return "unknown"

def build_lambda_string(inputs,string):

    lbda = "fn("

    p = 0
    for input in inputs.keys():

        if p == 0:
            lbda = lbda + input

        else:

            lbda = lbda + "," + input

        p = p + 1

    string = replace_function_inputs(string)

    lbda = lbda + ") -> " + string + " end"

    return lbda

def build_input_string(i,has_leading_bracket,has_trailing_bracket):

    input_string = ""

    if has_leading_bracket:
        input_string = "("

    input_string = "input" + str(i)

    if has_trailing_bracket:
        input_string = ")"

    return input_string

def build_inputs(var,model,lawstring,species_ids,definedFunctions,defined_parameters,compartment_sizes):

    operators = ['*','/',"+","-","="," "]

    string_split = lawstring.split(" ")
    inputs = {}
    i = 1
    for string in string_split:
        is_function = False

        if string in operators or is_number(string):
            continue

        else:
            parameter = None
            definedFunctionCheck = string.split("(")
            if len(definedFunctionCheck) > 1:
                function_string = definedFunctionCheck[0]

                if function_string in definedFunctions:
                    parameter = definedFunctionCheck[1].replace(")","")
                    is_function = True

            has_leading_bracket = False
            has_trailing_bracket = False

            if "(" in string and not is_function:
                has_leading_bracket = True
                string = string.replace("(","")
            if ")" in string and not is_function:
                has_trailing_bracket = True
                string = string.replace(")","")

            entity_type = find_entity_type(string,species_ids,defined_parameters,compartment_sizes)

        if entity_type == 'species':

            input_string = build_input_string(i,has_leading_bracket,has_trailing_bracket)
            node_specie_name = get_node_specie_name(string)

            if node_specie_name not in inputs:

                inputs[node_specie_name] = {"input_for_lambda":":" + get_node_specie_name(string),
                                            "input_name":input_string}
                i = i + 1

    return inputs

def build_ode_lambda_string(var,model,species_ids,lambda_string,inputs,definedFunctions,defined_parameters,compartment_sizes):

    lambda_explode = lambda_string.split(" ")

    operators = ['*','/',"+","-","(",")"," ",""]

    i = 1
    contains_function = False

    previous_was_function = False

    lambda_output = ""
    for string in lambda_explode:

        if string in operators:
            lambda_output = lambda_output + string
            continue

        if is_number(string):
            lambda_output = lambda_output + " " + string + " "
            continue

        is_function = False

        definedFunctionCheck = string.split("(")
        if len(definedFunctionCheck) > 1:
            string = definedFunctionCheck[0]

        if string in definedFunctions:
            string = definedFunctionCheck[1]
            is_function = True
            contains_function = True

        entity_type = find_entity_type(string,species_ids,defined_parameters,compartment_sizes)

        if entity_type == 'species':

            node_species_name = get_node_specie_name(string)
            lambda_input = inputs[node_species_name]
            input_name = lambda_input["input_name"]
            lambda_output = lambda_output + " " + input_name

        elif entity_type == 'compartment':

            lambda_output = lambda_output + " " + "1"

        elif entity_type == 'parameter':

            node_species_name = get_node_specie_name(string)
            lambda_output = lambda_output + " " + str(defined_parameters[node_species_name])

        lambda_output = lambda_output + " "
        i = i + 1

    if contains_function == True:
        #            print(lambda_output)
        lambda_output = lambda_output[:-1]


    lbda = "fn("

    p = 0
    for input in inputs.keys():

        if p == 0:
            lbda = lbda + inputs[input]["input_name"]
        else:
            lbda = lbda + "," + inputs[input]["input_name"]
        p = p + 1

    lbda = lbda + ") -> " + lambda_output + " end"

    return lbda

# Build the system of differential equations
#X = the process variable for the species.
#Loop through the reactions:
#    For the reactants - concatenate the reaction function as a subtraction.
#    ie dX/dt = (existing_function_definition) - new_reaction
#    For the products - contatenate the reaction function as an addition.
#    ie dX/dt = (existing_function_definition) + new_reaction
#Write out the functions.
def build_reaction_network_as_odes(model,compartment_species,species_ids,compartment_sizes):

    defined_parameters = {}
    parameters = model.getListOfParameters()
    for parameter in parameters:
        parameter_id = parameter.getId()
        defined_parameters[parameter_id] = parameter.getValue()

    initialAssignments = model.getListOfInitialAssignments()
    assignmentsForOverriding = {}
    for initialAssignment in initialAssignments:
        initial_assignment_id = initialAssignment.getId()
        assignmentsForOverriding[initial_assignment_id] = formulaToString(initialAssignment.math)

    definedFunctionList = model.getListOfFunctionDefinitions()
    definedFunctions = []
    for definedFunction in definedFunctionList:
        defined_function_id = definedFunction.getId()
        definedFunctions.append(definedFunction.id)

    odes = {}

    for compartment_name,specie in compartment_species.items():

        for specie_name,specie_dict in specie.items():

            edge_species_name = get_edge_specie_name(specie_name)
            odes[edge_species_name] = ""

    reactions = model.getListOfReactions()
    for reaction in reactions:

        kineticLaw = reaction.getKineticLaw()
        lawstring = formulaToString(kineticLaw.getMath())

        #        need to inject a space between all entities
        #        QRest * (CArt / VArt)
        #1. inject extra spaces after and before brackets
        #2. remove double spaces

        lawstring = lawstring.replace("(","( ")
        lawstring = lawstring.replace(")"," )")
        lawstring = re.sub(' +', ' ',lawstring)

        reactants = reaction.getListOfReactants()

        for reactant in reactants:
            edge_species_name = get_edge_specie_name(reactant.getSpecies())
            odes[edge_species_name] = odes[edge_species_name] + " - ( " + str(reactant.getStoichiometry()) + " * ( " + lawstring + " ) )"

        products = reaction.getListOfProducts()

        for product in products:
            edge_species_name = get_edge_specie_name(product.getSpecies())
            odes[edge_species_name] = odes[edge_species_name] + " + ( " + str(product.getStoichiometry()) + " * ( " + lawstring + " ) )"

    ode_edges = {}

    for var,ode in odes.items():

        inputs = build_inputs(var,model,ode,species_ids,definedFunctions,defined_parameters,compartment_sizes)
        lambda_string = build_ode_lambda_string(var,model,species_ids,ode,inputs,definedFunctions,defined_parameters,compartment_sizes)

        parsed_inputs = {}
        for node_name, input_data in inputs.items():
            parsed_inputs[input_data['input_name']] = input_data['input_for_lambda']

        output_odes = {}

        node_name = var.replace("pv_","")
        output_odes[":" + node_name] = "add"

        ode_edges[":" + var] = {'inputs':parsed_inputs, 'lambda':lambda_string, 'outputs':output_odes, 'partition':1 }

    return ode_edges

def import_from_sbml(sbml_filename):

    #sbml_filename = sbml_filename.decode("utf-8")

    reader = SBMLReader()
    document = reader.readSBMLFromFile(sbml_filename)
    model = document.getModel()

    compartments = model.getListOfCompartments()
    compartment_species = {}
    compartment_sizes = {}
    for compartment in compartments:
        compartment_id = compartment.getId()
        compartment_sizes[compartment_id] = compartment.getSize()
        compartment_species[compartment_id] = {}

    species = model.getListOfSpecies()
    species_ids = []
    all_species = {}
    for specie in species:
        id = specie.getId()
        species_ids.append(id)
        initialConcentration = specie.getInitialConcentration()
        compartment = specie.getCompartment()
        specie_dict = {"initial_value":initialConcentration}
        existing_species = compartment_species[compartment]
        all_species[id] = specie_dict
        existing_species[id] = specie_dict
        compartment_species[compartment] = existing_species

    ode_edges = build_reaction_network_as_odes(model,compartment_species,species_ids,compartment_sizes)

    nodes = {}

    for id,value in all_species.items():
        nodes[":" + id] = value

    partitions = { 1: {"solver_type": "ODE",
                       "start_step_size": 0.01,
                       "local_error_maximum": 1.0e-6,
                       "local_error_minimum": 1.0e-12,
                       "explicit_implicit_switch_step_size_tolerance":1.0e-3}
                   }


    config = {"nodes": nodes, "edges": ode_edges, "partitions":partitions}

    return config