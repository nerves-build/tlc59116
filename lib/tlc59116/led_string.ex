defmodule Tlc59116.LedString do
  defmodule State do
    defstruct leds: [],
              ref: nil,
              addr: nil,
              last_draw: nil,
              start_time: nil
  end

  use GenServer

  require Logger
  require Integer

  @i2c_handler Application.get_env(:tlc59116, Tlc59116, []) |> Keyword.get(:i2c_handler, Circuits.I2C)

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
              |> draw_all([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255])

            error ->
              Logger.error("Could not start LedString #{inspect(error)}")
              %{state | state: :disabled}
          end
      end

    {:ok, new_state}
  end

  def handle_call(:twinkle, _from, %{start_time: start_time} = state) do
    elapsed_tenths = Kernel.trunc((:os.system_time(:millisecond) - start_time) / 100)

    new_leds = case Integer.is_odd(elapsed_tenths) do
      true ->
          for i <- 0..14 do
            if Integer.is_odd(i) do
              255
            else
              0
            end
          end

      false ->
          for i <- 0..14 do
            if Integer.is_even(i) do
              255
            else
              0
            end
          end
    end

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call({:draw_value, value, 0}, _from, state) do
    inc = 100 / 15
    pins = Kernel.floor(value / inc)

    new_leds =
      for i <- 0..14 do
        if i == pins do
          20
        else
          0
        end
      end
      |> Enum.concat([40])

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call({:draw_value, value, fade}, _from, state) do
    inc = 100 / 15
    pins = Kernel.floor(value / inc)
    rem = (value - pins * inc) / inc * 255
    val = Kernel.trunc(255 * (fade / 100.0))

    new_leds =
      for i <- 0..14 do
        cond do
          i < pins ->
            val

          i > pins ->
            0

          true ->
            Kernel.floor(rem)
        end
      end
      |> Enum.concat([255])

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
