defmodule Vcnl4040.State do
  @moduledoc """
  State module for the Vcnl4040 GenServer.

  Separated out both to make code reloads easier
  and to separate out pure state operations from the
  fun and exciting world of messaging.
  """

  alias Vcnl4040.DeviceConfig
  @default_sample_interval 1000
  @default_buffer_size 9

  defstruct i2c_bus: nil,
            valid?: false,
            interrupt_pin: nil,
            bus_ref: nil,
            device_config: nil,
            interrupt_ref: nil,
            polling_sample_interval: @default_sample_interval,
            ambient_light: %{
              integration_time: 80,
              readings: nil,
              latest_lux: 0,
              latest_filtered: 0
            },
            proximity: %{
              integration_time: :t1,
              readings: nil,
              latest_value: 0,
              latest_filtered: 0
            },
            log_samples: false

  @als_integration_to_lux_step %{
    80 => 0.12,
    160 => 0.06,
    320 => 0.03,
    640 => 0.015
  }

  alias Vcnl4040.State, as: S

  def max_lux(%S{ambient_light: %{integration_time: it}}) do
    65536 * @als_integration_to_lux_step[it]
  end

  def als_sample_to_lux(%S{ambient_light: %{integration_time: it}}, sample) do
    round(@als_integration_to_lux_step[it] * sample)
  end

  def from_options(options) do
    interrupt_pin = Keyword.get(options, :interrupt_pin, nil)
    buffer_size = Keyword.get(options, :buffer_samples, @default_buffer_size)

    %S{
      i2c_bus: Keyword.get(options, :i2c_bus, "i2c-0"),
      device_config: Keyword.get(options, :device_config, DeviceConfig.new()),
      interrupt_pin: interrupt_pin,
      polling_sample_interval: Keyword.get(options, :poll_interval, 1000),
      ambient_light: %{
        als_integration_time: Keyword.get(options, :als_integration_time, 80),
        readings: CircularBuffer.new(buffer_size),
        latest_raw: 0,
        latest_lux: 0,
        latest_filtered: 0
      },
      proximity: %{
        integration_time: Keyword.get(options, :ps_integration_time, :t1),
        readings: CircularBuffer.new(buffer_size),
        latest_value: 0,
        latest_filtered: 0
      },
      log_samples: Keyword.get(options, :log_samples, false)
    }
  end

  def set_bus_ref(%S{} = s, bus_ref), do: %S{s | bus_ref: bus_ref}
  def set_valid(%S{} = s, valid?), do: %S{s | valid?: valid?}
  def set_interrupt_ref(%S{} = s, interrupt_ref), do: %S{s | interrupt_ref: interrupt_ref}

  def add_ambient_light_sample(%S{ambient_light: %{readings: readings} = a} = s, lux_value) do
    readings = CircularBuffer.insert(readings, lux_value)

    filtered_value =
      readings
      |> CircularBuffer.to_list()
      |> get_median()

    %S{
      ambient_light: %{
        a
        | readings: readings,
          latest_lux: lux_value,
          latest_filtered: filtered_value
      }
    }
  end

  def add_proximity_sample(%S{proximity: %{readings: readings} = p} = s, value) do
    readings = CircularBuffer.insert(readings, value)

    filtered_value =
      readings
      |> CircularBuffer.to_list()
      |> get_median()

    %S{
      proximity: %{
        p
        | readings: readings,
          latest_value: value,
          latest_filtered: filtered_value
      }
    }
  end

  defp get_median(list) do
    median_index = length(list) |> div(2)
    Enum.sort(list) |> Enum.at(median_index)
  end
end