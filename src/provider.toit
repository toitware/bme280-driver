// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import i2c
import sensors.providers

import .driver as bme280

NAME ::= "toit.io/bme280"
MAJOR ::= 1
MINOR ::= 0

class Sensor_
    implements
      providers.TemperatureSensor-v1
      providers.HumiditySensor-v1
      providers.PressureSensor-v1:
  sda_/gpio.Pin? := null
  scl_/gpio.Pin? := null
  i2c_/i2c.Bus? := null
  device_/i2c.Device? := null
  sensor_/bme280.Driver? := null

  constructor --sda/int --scl/int --address/int:
    is-exception := true
    try:
      sda_ = gpio.Pin sda
      scl_ = gpio.Pin scl
      i2c_ = i2c.Bus --sda=sda_ --scl=scl_
      device_ = i2c_.device address
      sensor_ = bme280.Driver device_
      is-exception = false
    finally:
      if is-exception:
        if device_: device_.close
        if i2c_: i2c_.close
        if sda_: sda_.close
        if scl_: scl_.close

  temperature-read -> float?:
    return sensor_.read-temperature

  humidity-read -> float:
    return sensor_.read-humidity

  pressure-read -> float:
    return sensor_.read-pressure

  close -> none:
    if sensor_:
      sensor_.close
      sensor_ = null
    if device_:
      device_.close
      device_ = null
    if i2c_:
      i2c_.close
      i2c_ = null
    if scl_:
      scl_.close
      scl_ = null
    if sda_:
      sda_.close
      sda_ = null

/**
Installs the BME280 sensor.
*/
install --sda/int --scl/int --address/int -> providers.Provider:
  provider := providers.Provider NAME
      --major=MAJOR
      --minor=MINOR
      --open=:: Sensor_ --sda=sda --scl=scl --address=address
      --close=:: it.close
      --handlers=[providers.TemperatureHandler-v1, providers.HumidityHandler-v1, providers.PressureHandler-v1]
  provider.install
  return provider
