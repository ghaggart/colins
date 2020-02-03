#https://elixirforum.com/t/code-priv-dir-doesnt-work-in-escript/4462/3
#def contents, do: unquote(File.read!("priv/foo"))

defmodule Colins.Erlport.Helper do
  @doc """
  ## Parameters
    - path: directory to include in python path (charlist)
  """
  #def python_instance(path) when is_list(path) do
  #  {:ok, pid} = :python.start([{:python,Path.join([File.cwd!,"python","erlport","env","bin","python3"])},}{:python_path, to_charlist(path)}])
  #  pid
  #end

  def python_instance() do
    IO.inspect(Path.join([Path.dirname(__ENV__.file),"python","env","bin","python3"]))
    IO.inspect(Path.join([Path.dirname(__ENV__.file),"python","modules"]))
    {:ok, pid} = :python.start([{:python,to_charlist(Path.join([Path.dirname(__ENV__.file),"python","env","bin","python3"]))},{:python_path,to_charlist(Path.join([Path.dirname(__ENV__.file),"python","modules"]))}])
    pid
  end

  @doc """
  Call python function using MFA format
  """
  def call_python(pid, module, function, arguments \\ []) do
    pid
    |>:python.call(module, function, arguments)

  end

  def stop_instance(pid) do

    pid
    |>:python.stop()

  end

  @doc "Take an expression string and a var string and differentiate"
  def differentiate(expr_string,var_string) do

    #IO.inspect(expr_string)
    #IO.inspect(var_string)
    #aSystem.halt(0)

    pid = Colins.Erlport.Helper.python_instance()
    partial_derivative_functions = Colins.Erlport.Helper.call_python(pid,String.to_atom("sympy_functions"),String.to_atom("differentiate_and_take_partial_derivatives"),[convert_math_elixir_to_python(expr_string),var_string])
    Colins.Erlport.Helper.stop_instance(pid)
    partial_derivative_functions

  end

  def convert_math_elixir_to_python(expr_string) do

    String.replace(expr_string, "^", "**", [:global,true])
  end

  def test_differentiate() do

    dydx_expr_string = "(x - y)/2"
    var_string = "x,y"
    pid = Colins.Erlport.Helper.python_instance()
    Colins.Erlport.Helper.call_python(pid,String.to_atom("sympy_functions"),String.to_atom("differentiate_and_take_partial_derivatives"),[dydx_expr_string,var_string])

  end

  def import_config_from_sbml(model_filename) do
      pid = Colins.Erlport.Helper.python_instance()
      yaml_config = Colins.Erlport.Helper.call_python(pid,String.to_atom("sbml_convert"),String.to_atom("import_from_sbml"),[model_filename])
      Colins.Erlport.Helper.stop_instance(pid)
      yaml_config

  end


end