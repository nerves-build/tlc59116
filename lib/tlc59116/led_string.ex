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
  @actions [:normal, :sparkle]

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
              |> handle_draw_value(0, 100)

            error ->
              Logger.error("Could not start LedString #{inspect(error)}")
              %{state | state: :disabled}
          end
      end

    {:ok, new_state}
  end

  def handle_call(action, _from, %{initialized: false} = state) when action in @actions do
    {:reply, state, state}
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
        %{state | state: :disabled}
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
end
