defmodule Tlc59116.LedString do
  defmodule State do
    defstruct leds: [],
              ref: nil,
              addr: nil,
              initialized: false,
              last_draw: nil,
              start_time: nil
  end

  use GenServer

  require Logger
  require Integer

  @i2c_handler Application.get_env(:tlc59116, Tlc59116, [])
               |> Keyword.get(:i2c_handler, Circuits.I2C)
  @modes [:normal, :sparkle, :cylon]

  def start_link(_vars) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  def draw_value(value, fade) do
    GenServer.call(__MODULE__, {:draw_value, value, fade})
  end

  def twinkle() do
    GenServer.call(__MODULE__, :twinkle)
  end

  def modes do
    @modes
  end

  def cylon() do
    GenServer.call(__MODULE__, :cylon)
  end

  def init(state) do
    opts = Application.get_env(:tlc59116, Tlc59116, [])

    new_state =
      case Keyword.get(opts, :led_base_address) do
        nil ->
          state

        addr ->
          %{state | addr: addr}
          |> open_handler()
          |> start_pins()
          |> handle_draw_value(0, 100)
      end

    {:ok, new_state}
  end

  def handle_call(action, _from, %{initialized: false} = state) when action in @modes do
    {:reply, state, state}
  end

  def handle_call(:cylon, _from, %{start_time: start_time} = state) do
    elapsed_tenths = Kernel.trunc((:os.system_time(:millisecond) - start_time) / 100) |> rem(18)

    new_leds =
      elapsed_tenths
      |> generate_cylon()
      |> generate_on_lite

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call(:twinkle, _from, %{start_time: start_time} = state) do
    elapsed_tenths = Kernel.trunc((:os.system_time(:millisecond) - start_time) / 500)

    new_leds =
      elapsed_tenths
      |> Integer.is_odd()
      |> generate_twinkle()
      |> generate_on_lite

    new_state = draw_all(state, new_leds)

    {:reply, new_state, new_state}
  end

  def handle_call({:draw_value, value, fade}, _from, state) do
    new_state = handle_draw_value(state, value, fade)

    {:reply, new_state, new_state}
  end

  defp open_handler(state) do
    case @i2c_handler.open("i2c-1") do
      {:ok, ref} ->
        %{
          state
          | ref: ref,
            start_time: :os.system_time(:millisecond)
        }

      error ->
        Logger.error("Could not start LedString #{inspect(error)}")
        state
    end
  end

  defp generate_level({pins, val, rem}) do
    for i <- 0..14 do
      cond do
        i < pins ->
          val

        i > pins ->
          0

        true ->
          rem
      end
    end
  end

  defp handle_draw_value(%{initialized: false} = state, _value, _fade), do: state

  defp handle_draw_value(state, value, fade) do
    new_leds =
      value
      |> generate_level_params(fade)
      |> generate_level
      |> generate_on_lite

    draw_all(state, new_leds)
  end

  defp generate_level_params(0, 0), do: {15, 0, 0}

  defp generate_level_params(value, 0) do
    inc = 100 / 15
    pins = Kernel.floor(value / inc)
    {pins, 0, 20}
  end

  defp generate_level_params(value, fade) do
    inc = 100 / 15
    pins = Kernel.floor(value / inc)
    rem = (value - pins * inc) / inc * 255
    val = Kernel.trunc(255 * (fade / 100.0))

    {pins, val, Kernel.floor(rem)}
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

  defp start_pins(%{ref: nil} = state), do: state

  defp start_pins(%{ref: ref, addr: addr} = state) do
    case @i2c_handler.write(ref, addr, <<0x00, 0x0F>>) do
      :ok ->
        :ok = @i2c_handler.write(ref, addr, <<0x14, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x15, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x16, 0xFF>>)
        :ok = @i2c_handler.write(ref, addr, <<0x17, 0xFF>>)
        %{state | initialized: true}

      error ->
        Logger.error("Could not write LedString to #{inspect(error)}")
        state
    end
  end

  defp generate_twinkle(start_on) do
    for i <- 0..14 do
      if should_be_on(start_on, i) do
        255
      else
        0
      end
    end
  end

  defp should_be_on(true, i), do: Integer.is_odd(i)
  defp should_be_on(false, i), do: Integer.is_even(i)

  defp generate_on_lite(leds), do: Enum.concat(leds, [255])

  defp generate_cylon(0), do: [30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(1), do: [0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(2), do: [0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(3), do: [0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(4), do: [0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(5), do: [0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0]
  defp generate_cylon(6), do: [0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0]
  defp generate_cylon(7), do: [0, 0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0]
  defp generate_cylon(8), do: [0, 0, 0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0]
  defp generate_cylon(9), do: [0, 0, 0, 0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 30]
  defp generate_cylon(10), do: [0, 0, 0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0]
  defp generate_cylon(11), do: [0, 0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0]
  defp generate_cylon(12), do: [0, 0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0]
  defp generate_cylon(13), do: [0, 0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0]
  defp generate_cylon(14), do: [0, 0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(15), do: [0, 0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(16), do: [0, 0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0, 0]
  defp generate_cylon(17), do: [0, 30, 100, 220, 100, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0]
end
