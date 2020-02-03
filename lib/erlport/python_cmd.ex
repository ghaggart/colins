#https://elixirforum.com/t/code-priv-dir-doesnt-work-in-escript/4462/3
#def contents, do: unquote(File.read!("priv/foo"))

defmodule Colins.Erlport.PythonCmd do
  @doc """
  ## Parameters
    - path: directory to include in python path (charlist)
  """

  def python_path() do
    Path.join([Path.dirname(__ENV__.file),"python","env","bin","python3"])
  end

  @doc "Take an expression string and a var string and differentiate"
  def differentiate(expr_string,var_string) do

    script_path = Path.join([Path.dirname(__ENV__.file),"python","modules","differentiate.py"])
    { python_yaml, _ } = System.cmd(python_path(),[script_path,convert_math_elixir_to_python(expr_string),var_string])
    [ partial_derivative_function | _ ] = YamlElixir.read_all_from_string(python_yaml)
    partial_derivative_function

  end

  def convert_math_elixir_to_python(expr_string) do

    String.replace(expr_string, "^", "**", [:global,true])
  end

  def import_config_from_sbml(model_filename) do

    script_path = Path.join([Path.dirname(__ENV__.file),"python","modules","import_from_sbml.py"])
    { python_yaml, _ } = System.cmd(python_path(),[script_path,model_filename])
    [ yaml_config | _ ] = YamlElixir.read_all_from_string(python_yaml,atoms: true)
    yaml_config

  end


end