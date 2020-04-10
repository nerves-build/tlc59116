defmodule Tlc59116.MockI2CPin do
  @moduledoc false

  def open(_pin_name) do
    {:ok, :mock}
  end

  def write(_gpio, _type, _data) do
    :ok
  end

  def set_interrupts(_gpio, _type) do
    :ok
  end
end
