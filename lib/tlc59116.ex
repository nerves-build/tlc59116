defmodule Tlc59116 do
  @moduledoc """
  Documentation for Tlc59116.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Tlc59116.hello()
      :world

  """
  def set_mode(mode) do
    :ok
  end

  def set_level(value) do
    Tlc59116.LedString.set_value(value)
  end
end
