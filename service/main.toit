// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import encoding.tison
import system.assets
import bme280.provider
import bme280 show I2C-ADDRESS I2C-ADDRESS-ALT

install-from-args_ args/List:
  if args.size != 3:
    throw "Usage: main <scl> <sda> <address>"
  scl := int.parse args[0]
  sda := int.parse args[1]
  address-str/string := args[2]
  address/int := ?
  if address-str == "":
    address = I2C-ADDRESS
  else if address-str.to-ascii-lower == "alt":
    address = I2C-ADDRESS-ALT
  else:
    address = int.parse address-str
  provider.install --scl=scl --sda=sda --address=address

install-from-assets_ configuration/Map:
  scl := configuration.get "scl"
  if not scl: throw "No 'scl' found in assets."
  if scl is not int: throw "SCL must be an integer."
  sda := configuration.get "sda"
  if not sda: throw "No 'sda' found in assets."
  if sda is not int: throw "SDA must be an integer."
  address := configuration.get "address"
  if not address:
    address = I2C-ADDRESS
  else if address is string and address.to-ascii-lower == "alt":
    address = I2C-ADDRESS-ALT
  else if not address is int:
    throw "Address must be an integer or 'alt'."
  provider.install --scl=scl --sda=sda --address=address

main args:
  // Arguments take priority over assets.
  if args.size != 0:
    install-from-args_ args
    return

  decoded := assets.decode
  ["configuration", "artemis.defines"].do: | key/string |
    configuration := decoded.get key
    if configuration:
      install-from-assets_ configuration
      return

  throw "No configuration found."
