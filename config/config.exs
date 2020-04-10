use Mix.Config

config :tlc59116, Tlc59116,
  led_base_address: 0x68,
  fade_start: 1000 * 60 * 5,
  fade_end: 1000 * 60 * 15

if Mix.target() != :host do
  import_config "target.exs"
else
  import_config "host.exs"
end
