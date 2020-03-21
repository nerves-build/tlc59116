defmodule Tlc59116.LedString do
  defmodule State do
    defstruct leds: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
              mode: :standard,
              state: :off,
              ref: nil,
              addr: nil
  end

  use GenServer

  alias Circuits.I2C

  require Logger

  @interval 50

  def start_link(_vars) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_value(new_val) do
    GenServer.call(__MODULE__, {:set_value, new_val})
  end

  def init(state) do
    opts = Application.get_env(:tlc59116, Tlc59116.LedString, [])

    new_state =
      case Keyword.get(opts, :led_base_address) do
        nil ->
          state

        addr ->
          case I2C.open("i2c-1") do
            {:ok, ref} ->
              %{state | ref: ref, state: :idle, addr: addr}
              |> start_pins()

            error ->
              Logger.warn("Could not start LedString #{inspect(error)}")
              state
          end
      end

    {:ok, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_value, new_val}, _from, state) do
    inc = 100 / 16
    new_val = String.to_integer(new_val)
    pins = Kernel.floor(new_val / inc)
    rem = (new_val - pins * inc) / inc * 255

    new_leds =
      for i <- 0..15 do
        cond do
          i < pins ->
            255

          i > pins ->
            0

          true ->
            Kernel.floor(rem)
        end
      end

    new_state =
      %{state | leds: new_leds}
      |> draw_all()

    {:reply, new_state, new_state}
  end

  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @interval)

    draw_all(state)

    {:noreply, state}
  end

  defp draw_all(%{ref: ref, addr: addr, leds: leds} = state) do
    for {val, ind} <- Enum.with_index(leds) do
      I2C.write(ref, addr, <<0x02 + ind, val>>)
    end

    state
  end

  defp start_pins(%{ref: ref, addr: addr} = state) do
    if I2C.write(ref, addr, <<0x00, 0x0F>>) == :ok do
      :ok = I2C.write(ref, addr, <<0x14, 0xFF>>)
      :ok = I2C.write(ref, addr, <<0x15, 0xFF>>)
      :ok = I2C.write(ref, addr, <<0x16, 0xFF>>)
      :ok = I2C.write(ref, addr, <<0x17, 0xFF>>)
    end

    state
  end
end
