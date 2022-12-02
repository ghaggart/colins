# Colins numerical simulator

COLINS is a concurrent, adaptive, multi-rate, multi-method, numerical solver for dynamical systems. 

Dynamical systems are represented as a network of nodes and edges.

Nodes and edges are grouped into independent partitions.

Different partitions can be run with different solver types (ie deterministic ODE, stochastic ODE), with different time-steps.

(Solver types implemented: Basic, Euler, RungeKutta4, RungeKuttaFelhberg, BackwardEuler)

Networks can be defined using SBML or the in-built, domain-agnostic language specification (DaSL), in YAML:
(Antimony coming soon)

```YAML
# dy/dx = (x-y)/2
# Using adaptive deterministic solver (RKF56 and BackwardEuler) 
partitions:
    1:
        solver_type: ODE
        start_step_size: 0.1
        local_error_maximum: 1.0e-6
        local_error_minimum: 1.0e-12
        explicit_implicit_switch_step_size_tolerance: 1.0e-4
nodes:
    :node_y:
        initial_value: 1
    :timepoint:
        initial_value: 0
edges:
    :y_equals_x:
        partition: 1
        inputs:
            input1: :timepoint
            input2: :node_y
        lambda: fn(input1,input2) -> (input1 - input2)/2 end
        outputs:
            :node_y: add
```

Uses SymPy for calculating Jacobian, and libSBML for parsing SBML.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `colins` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:colins, "~> 0.1.0"}
  ]
end
```

Create a python environment containing the following packages:

sympy
python-libsbml
pyyaml

In your dev.exs or prod.exs file specify the python_path:

```elixir
config :colins, python_path: "/rds/general/user/ghaggart/home/anaconda3/envs/colins/bin/python"
```

If you plan to use COLINS as a standalone executable, you must compile into an escript.

To do so, run the following command:

cd colins
rm -rf deps && rm -rf _build
mix deps.get && MIX_ENV=prod mix compile && MIX_ENV=prod mix escript.build

## Usage

Either use as part of another Elixir/Erlang program, or use the command line executable:

./colins -n '/path/to/model_file/' -f '/path/to/results' -l <max_timepoint> -m <mesh_size> -i <sim_name>




## Copyright 
© - Gordon Haggart 2020 - All rights reserved.
