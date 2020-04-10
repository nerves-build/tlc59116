use Mix.Config

config :tlc59116, Tlc59116, i2c_handler: Tlc59116.MockI2CPin

config :tlc59116, Tlc59116.LedString,
  led_base_address: 0x68,
  fade_start: 1000 * 60 * 60 * 10,
  fade_end: 1000 * 60 * 60 * 20
