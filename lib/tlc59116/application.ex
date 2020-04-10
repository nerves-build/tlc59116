defmodule Tlc59116.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Tlc59116.LedString,
      Tlc59116.Ticker
    ]

    opts = [strategy: :one_for_one, name: Tlc59116.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
