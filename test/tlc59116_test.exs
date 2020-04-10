defmodule Tlc59116Test do
  use ExUnit.Case
  doctest Tlc59116

  describe "set_mode" do
    test "can change to a valid state" do
      %{mode: mode} = Tlc59116.set_mode(:sparkle)
      assert mode == :sparkle

      %{mode: mode} = Tlc59116.set_mode(:normal)
      assert mode == :normal
    end

    test "cannot change to an invalid state" do
      %{mode: mode} = Tlc59116.set_mode(:bobo)
      assert mode == :normal
    end
  end

  describe "set_value" do
    test "can change to a valid state" do
      %{value: value} = Tlc59116.set_value(80)
      assert value == 80
    end

    test "cannot change to a negative value" do
      %{value: value} = Tlc59116.set_value(-5)
      assert value == 0
    end

    test "cannot change to greater than 100" do
      %{value: value} = Tlc59116.set_value(102)
      assert value == 100
    end
  end
end
