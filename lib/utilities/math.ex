defmodule Colins.Utilities.Math do

  def remainder_zero?(a,n) do

    #Float.to_string(a/n)
    #|> String.slice(-1..-1)

    # Get the final digit and check if it is zero or not.

    #0.0 = remainder 0
    #0.1, 0.1307, etc = remainder not 0
    terminal_num = String.slice(Float.to_string(a/n), -1..-1)

    case String.to_integer(terminal_num) do

      x when (x == 0) -> true
      x when (x != 0) -> false

    end

  end

  def number_of_decimal_places(number) do

    mesh_size_string = Float.to_string(number)

    case String.contains?(mesh_size_string,["e"]) do

      # calculate based 1.0e-5
      true -> [ rhs | _ ] = Enum.reverse(String.split(mesh_size_string,"e"))
              (0 - String.to_integer(rhs)) + 1

      # calculate based on 0.01
      false -> [ rhs | _ ] = Enum.reverse(String.split(mesh_size_string,"."))
               String.length(rhs)

    end

  end


  @doc "Make negative values positive"
  def sign_pos(value) do

    case value do
      value when value < 0 -> (0-value)

      value -> value
    end

  end

  def convert_math_to_elixir(lambda_string) do

      lambda_string = String.replace(lambda_string,"sin",":math.sin")
      lambda_string = String.replace(lambda_string,"cos",":math.cos")
      lambda_string = String.replace(lambda_string,"tan",":math.tan")
      lambda_string = String.replace(lambda_string,"exp",":math.exp")
      lambda_string = String.replace(lambda_string,"log",":math.log")
      lambda_string = String.replace(lambda_string,"log10",":math.log10")
      lambda_string = String.replace(lambda_string,"log2",":math.log2")
      lambda_string = String.replace(lambda_string,"pow",":math.pow")
      lambda_string = String.replace(lambda_string,"sqrt",":math.sqrt")
      String.replace(lambda_string,"pi",":math.pi")

  end

end
