defmodule Colins.Utilities.Modulo do

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

end