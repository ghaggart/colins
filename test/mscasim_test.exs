defmodule ColinsTest do
  use ExUnit.Case
  doctest Colins

  test "greets the world" do
    assert Colins.hello() == :world
  end
end
