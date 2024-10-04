// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import binary
import serial.device as serial
import serial.registers as serial

I2C-ADDRESS     ::= 0x76
I2C-ADDRESS-ALT ::= 0x77

/**
Driver for the Bosch BME280 environmental sensor, using either I2C or SPI.
*/
class Driver:
  static DIG-T1-REG_ ::= 0x88
  static DIG-T2-REG_ ::= 0x8A
  static DIG-T3-REG_ ::= 0x8C

  static DIG-P1-REG_ ::= 0x8E
  static DIG-P2-REG_ ::= 0x90
  static DIG-P3-REG_ ::= 0x92
  static DIG-P4-REG_ ::= 0x94
  static DIG-P5-REG_ ::= 0x96
  static DIG-P6-REG_ ::= 0x98
  static DIG-P7-REG_ ::= 0x9A
  static DIG-P8-REG_ ::= 0x9C
  static DIG-P9-REG_ ::= 0x9E

  static DIG-H1-REG_ ::= 0xA1
  static DIG-H2-REG_ ::= 0xE1
  static DIG-H3-REG_ ::= 0xE3
  static DIG-H4-REG_ ::= 0xE4
  static DIG-H5-REG_ ::= 0xE5
  static DIG-H6-REG_ ::= 0xE7

  static REGISTER-CHIPID_       ::= 0xD0
  static REGISTER-VERSION_      ::= 0xD1
  static REGISTER-RESET_        ::= 0xE0
  static REGISTER-CAL26_        ::= 0xE1
  static REGISTER-CONTROL-HUM_  ::= 0xF2
  static REGISTER-STATUS_       ::= 0xF3
  static REGISTER-CONTROL-MEAS_ ::= 0xF4
  static REGISTER-CONFIG_       ::= 0xF5
  static REGISTER-PRESSUREDATA_ ::= 0xF7
  static REGISTER-TEMPDATA_     ::= 0xFA
  static REGISTER-HUMIDDATA_    ::= 0xFD

  reg_/serial.Registers ::= ?

  dig-T1_ := null
  dig-T2_ := null
  dig-T3_ := null

  dig-P1_ := null
  dig-P2_ := null
  dig-P3_ := null
  dig-P4_ := null
  dig-P5_ := null
  dig-P6_ := null
  dig-P7_ := null
  dig-P8_ := null
  dig-P9_ := null

  dig-H1_ := null
  dig-H2_ := null
  dig-H3_ := null
  dig-H4_ := null
  dig-H5_ := null
  dig-H6_ := null

  constructor dev/serial.Device:
    reg_ = dev.registers

    // The official Bosch sample tries to read the CHIP ID
    // 5 times and pauses for one millisecond between the
    // reads. We do the same.
    tries := 5
    while (reg_.read-u8 REGISTER-CHIPID_) != 0x60:
      tries--
      if tries == 0: throw "INVALID_CHIP"
      sleep --ms=1

    reset_

    read-calibration-data_

    // Sleep mode, we only measure when needed.
    reg_.write-u8 REGISTER-CONTROL-MEAS_ 0b000_000_00

    reg_.write-u8 REGISTER-CONFIG_ 0b000_000_0_0
    reg_.write-u8 REGISTER-CONTROL-HUM_ 0b00000_001 // Set before CONTROL (DS 5.4.3)

  close:
    reg_.write-u8 REGISTER-CONTROL-MEAS_ 0b000_000_00

  /**
  Reads the temperature and returns it in degrees Celsius.
  */
  read-temperature -> float:
    t-fine := measure_

    temperature := (t-fine * 5 + 128) >> 8
    return temperature / 100.0

  /**
  Reads the pressure and returns it in Pascals.
  */
  read-pressure -> float:
    t-fine := measure_

    adc-P := reg_.read-u24-be REGISTER-PRESSUREDATA_
    adc-P >>= 4

    var1 := t-fine - 128000
    var2 := var1 * var1 * dig-P6_
    var2 = var2 + ((var1 * dig-P5_) << 17)
    var2 = var2 + (dig-P4_ << 35)
    var1 = ((var1 * var1 * dig-P3_) >> 8) + ((var1 * dig-P2_) << 12)
    var1 = (((1 << 47) + var1) * dig-P1_) >> 33

    if var1 == 0: return 0.0  // Avoid exception caused by division by zero.

    p := 1048576 - adc-P
    p = (((p << 31) - var2) * 3125) / var1
    var1 = (dig-P9_ * (p >> 13) * (p >> 13)) >> 25
    var2 = (dig-P8_ * p) >> 19

    p = ((p + var1 + var2) >> 8) + (dig-P7_ << 4)
    return p/256.0

  /**
  Reads the relative humidity and returns it as a percent in the range `0.0 - 100.0`.
  */
  read-humidity -> float:
    t-fine := measure_

    adc-H := reg_.read-u16-be REGISTER-HUMIDDATA_

    v-x1-u32r := t-fine - 76800

    v-x1-u32r = ((((adc-H << 14) - (dig-H4_ << 20) - (dig-H5_ * v-x1-u32r)) + 16384) >> 15) *
                 (((((((v-x1-u32r * dig-H6_) >> 10) *
                      (((v-x1-u32r * dig-H3_) >> 11) + 32768)) >> 10) +
                    2097152) * dig-H2_ + 8192) >> 14)

    v-x1-u32r = v-x1-u32r - (((((v-x1-u32r >> 15) * (v-x1-u32r >> 15)) >> 7) * dig-H1_) >> 4)

    v-x1-u32r = (v-x1-u32r < 0) ? 0 : v-x1-u32r
    v-x1-u32r = (v-x1-u32r > 419430400) ? 419430400 : v-x1-u32r
    h := v-x1-u32r >> 12
    return h / 1024.0;

  read-calibration-data_:
    dig-T1_ = reg_.read-u16-le DIG-T1-REG_
    dig-T2_ = reg_.read-i16-le DIG-T2-REG_
    dig-T3_ = reg_.read-i16-le DIG-T3-REG_

    dig-P1_ = reg_.read-u16-le DIG-P1-REG_
    dig-P2_ = reg_.read-i16-le DIG-P2-REG_
    dig-P3_ = reg_.read-i16-le DIG-P3-REG_
    dig-P4_ = reg_.read-i16-le DIG-P4-REG_
    dig-P5_ = reg_.read-i16-le DIG-P5-REG_
    dig-P6_ = reg_.read-i16-le DIG-P6-REG_
    dig-P7_ = reg_.read-i16-le DIG-P7-REG_
    dig-P8_ = reg_.read-i16-le DIG-P8-REG_
    dig-P9_ = reg_.read-i16-le DIG-P9-REG_

    dig-H1_ = reg_.read-u8 DIG-H1-REG_
    dig-H2_ = reg_.read-i16-le DIG-H2-REG_
    dig-H3_ = reg_.read-u8 DIG-H3-REG_
    dig-H4_ = ((reg_.read-i8 DIG-H4-REG_) << 4) | ((reg_.read-u8 DIG-H4-REG_+1) & 0xF)
    dig-H5_ = ((reg_.read-i8 DIG-H5-REG_+1) << 4) | ((reg_.read-u8 DIG-H5-REG_) >> 4)
    dig-H6_ = reg_.read-i8 DIG-H6-REG_

  wait-for-measurement_:
    16.repeat:
      val := reg_.read-u8 REGISTER-STATUS_
      if val & 0b1001 == 0: return
      sleep --ms=it + 1  // Back off slowly.
    throw "BME280: Unable to measure"

  measure_:
    reg_.write-u8 REGISTER-CONTROL-MEAS_ 0b001_001_01

    // Wait for measurement to start; typical time for full measurement using
    // 1x oversampling on all sensors.
    //   1 + [2 * 1] + [2 * 1 + 0.5] + [2 * 1 + 0.5] = 8
    sleep --ms=8
    // Wait until measurement is done.
    wait-for-measurement_

    adc-T := reg_.read-u24-be REGISTER-TEMPDATA_

    adc-T >>= 4;

    var1 := (((adc-T >> 3) - (dig-T1_ << 1)) * dig-T2_) >> 11
    var2 := (adc-T >> 4) - dig-T1_
    var2 = (((var2 * var2) >> 12) * (dig-T3_)) >> 14

    return var1 + var2

  reset_:
    reg_.write-u8 REGISTER-RESET_ 0xB6

    // Wait until reset is done.
    8.repeat:
      sleep --ms=2  // As per data sheet - Table 1, startup time is 2 ms.
      catch:
        val := reg_.read-u8 REGISTER-STATUS_
        if val & 0b1 == 0: return
    throw "BME280: Unable to reset"
