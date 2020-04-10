defmodule Tlc59116.LedString do
  defmodule State do
    defstruct leds: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
              ref: nil,
              addr: nil,
              start_time: nil
  end

  use GenServer

  require Logger

  @i2c_handler Application.get_env(:tlc59116, Tlc59116, [])
               |> Keyword.get(:i2c_handler, Circuits.I2C)

  def start_link(_vars) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  def draw_value(value, fade) do
    GenServer.call(__MODULE__, {:draw_value, value, fade})
  end

  def twinkle() do
    GenServer.call(__MODULE__, :twinkle)
  end

  def init(state) do
    opts = Application.get_env(:tlc59116, Tlc59116, [])

    new_state =
      case Keyword.get(opts, :led_base_address) do
        nil ->
          state

        addr ->
          case @i2c_handler.open("i2c-1") do
            {:ok, ref} ->
              %{
                state
                | ref: ref,
                  addr: addr,
                  start_time: :os.system_time(:millisecond)
              }
              |> start_pins()

            error ->
              Logger.error("Could not start LedString #{inspect(error)}")
              %{state | state: :disabled}
          end
      end

    {:ok, new_state}
  end

  def handle_call(:twinkle, _from, %{start_time: start_time} = state) do
    elapsed_tenths = Kernel.trunc((:os.system_time(:milliseconds) - start_time) / 100)

    new_leds =
      for i <- 0..15 do
        Kernel.rem(elapsed_tenths + i, 3) * 80
      end

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call({:draw_value, value, 0}, _from, state) do
    inc = 100 / 16
    pins = Kernel.floor(value / inc)
    IO.puts("drawing the value #{value} with fade #{0}")

    new_leds =
      for i <- 0..15 do
        if i == pins do
          20
        else
          0
        end
      end

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call({:draw_value, value, fade}, _from, state) do
    inc = 100 / 16
    pins = Kernel.floor(value / inc)
    rem = (value - pins * inc) / inc * 255
    IO.puts("drawing the value #{value} with fade #{fade}")

    new_leds =
      for i <- 0..15 do
        cond do
          i < pins ->
            255 * fade

          i > pins ->
            0

          true ->
            Kernel.floor(rem)
        end
      end

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  defp draw_all(%{ref: ref, addr: addr, leds: leds} = state, new_leds) do
    for {val, ind} <- Enum.with_index(new_leds) do
      if val != Enum.at(leds, ind) do
        case @i2c_handler.write(ref, addr, <<0x02 + ind, val>>) do
          :ok ->
            :ok

          error ->
            Logger.error("Could not write LedString #{inspect(error)}")
        end
      end
    end

    %{state | leds: new_leds}
  end

  defp start_pins(%{ref: ref, addr: addr} = state) do
    case @i2c_handler.write(ref, addr, <<0x00, 0x0F>>) do
      :ok ->
        :ok = @i2c_handler.write(ref, addr, <<0x14, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x15, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x16, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x17, 0xFF>>)
        state

      error ->
        Logger.error("Could not write LedString to #{inspect(error)}")
        %{state | state: :disabled}
    end
  end
end
