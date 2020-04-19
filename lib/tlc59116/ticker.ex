defmodule Tlc59116.Ticker do
  defmodule State do
    defstruct mode: :normal,
              start_time: 0,
              last_event: 0,
              fade_start: nil,
              fade_end: nil,
              value: 0
  end

  use GenServer

  require Logger

  alias Tlc59116.LedString

  @interval 100
  @two_hours 1000 * 60 * 60 * 2
  @three_hours 1000 * 60 * 60 * 3
  @modes LedString.modes()

  def start_link(_vars) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_value(new_val) do
    GenServer.call(__MODULE__, {:set_value, new_val})
  end

  def set_mode(new_mode) do
    GenServer.call(__MODULE__, {:set_mode, new_mode})
  end

  def init(state) do
    opts = Application.get_env(:tlc59116, Tlc59116, [])
    Process.send_after(self(), :tick, @interval)

    new_state = %{
      state
      | fade_start: Keyword.get(opts, :fade_start, @two_hours),
        fade_end: Keyword.get(opts, :fade_end, @three_hours),
        start_time: :os.system_time(:millisecond)
    }

    {:ok, new_state}
  end

  def handle_call({:set_value, new_val}, _from, state) do
    true_value = new_val |> Kernel.min(100) |> Kernel.max(0)
    new_state = %{state | value: true_value, last_event: :os.system_time(:millisecond)}
    {:reply, new_state, new_state}
  end

  def handle_call({:set_mode, new_mode}, _from, state) when new_mode in @modes do
    new_state = %{state | mode: new_mode, last_event: :os.system_time(:millisecond)}
    {:reply, new_state, new_state}
  end

  def handle_call(_, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @interval)

    state = handle_tick(state)

    {:noreply, state}
  end

  defp handle_tick(%{mode: :sparkle} = state) do
    LedString.sparkle()
    state
  end

  defp handle_tick(%{mode: :cylon} = state) do
    LedString.cylon()
    state
  end

  defp handle_tick(%{mode: :normal} = state) do
    tick_time = :os.system_time(:millisecond)

    handle_normal(state, tick_time)
    state
  end

  defp handle_normal(%{value: value, last_event: last_event, fade_end: fade_end}, tick_time)
       when last_event + fade_end < tick_time do
    LedString.draw_value(value, 0)
  end

  defp handle_normal(
         %{value: value, last_event: last_event, fade_start: fade_start},
         tick_time
       )
       when last_event + fade_start > tick_time do
    LedString.draw_value(value, 100)
  end

  defp handle_normal(
         %{value: value, last_event: last_event, fade_start: fade_start, fade_end: fade_end},
         tick_time
       ) do
    fade_range = fade_end - fade_start
    event_time = tick_time - last_event
    fade_val = event_time / fade_range * 100

    LedString.draw_value(value, 100 - Kernel.floor(fade_val))
  end
end
