# Probe: RP2040 Pmod plugged into the Arty

The ControlPaths RP2040 Pmod (<https://www.controlpaths.com/2023/12/23/rp2040-pmod-usb-bridge>) can
be the SWD master in place of an MCU-Link. It plugs straight into Arty Pmod JB: no leads, no
breakout, no VTREF wire. The target does not change, and `openocd/swdcap.cfg` is used as is.

The Pmod ships with a USB-UART image. OpenOCD needs a CMSIS-DAP interface, so the Pmod is flashed
with Raspberry Pi `debugprobe`, changed for this connector: branch `rp2040-pmod` of
<https://github.com/disdi/debugprobe/tree/rp2040-pmod>.

This probe has no VTREF pin (both Pmod supply pins are not connected on the board; it runs from
its own regulator on USB). It does not replace the MCU-Link for a VTREF check.

## Status

Hardware-verified 2026-10-04 on an Arty A7-35T, Pmod in JB, `boards/arty/swdcap_arty.py` build,
OpenOCD master:

| Check | 1 MHz | 4 MHz |
|---|---|---|
| `p1_check` | PASS | PASS |
| `p1_stress 2000` | PASS | PASS |
| `p2_check` | PASS | PASS |

## Pin map

J1 on the Pmod is numbered in column pairs (1/2, 3/4, ... 11/12). Pin 1 has the square pad; it and
the other odd pins are the inner row, which on the right-angle header is the row further from the
PCB. The back silkscreen prints the GPIO numbers under the pads.

Plugged into a Pmod host port, component side up:

| Host Pmod pin (top / bottom row) | J1 pins | Pmod net |
|---|---|---|
| 1 / 7 | 11 / 12 | GPIO 0 / **GPIO 1** |
| 2 / 8 | 9 / 10 | GPIO 16 / GPIO 17 |
| 3 / 9 | 7 / 8 | **GPIO 18** / GPIO 19 |
| 4 / 10 | 5 / 6 | GPIO 20 / GPIO 21 |
| 5 / 11 | 3 / 4 | GND / GND |
| 6 / 12 | 1 / 2 | not connected |

The swdcap pads are Pmod pin 3 (SWCLK) and pin 7 (SWDIO), so the probe drives **SWCLK on GPIO 18
and SWDIO on GPIO 1**. The other GPIOs on the connector meet unused FPGA pins and stay inputs.

## Firmware

Source: <https://github.com/disdi/debugprobe/tree/rp2040-pmod>, one commit (`08c0116`) on
<https://github.com/raspberrypi/debugprobe> `262f962`. pico-sdk 2.3.0 or later (built with 2.3.1).
The commit changes three files:

| File | Change |
|---|---|
| `include/board_pico_config.h` | `PROBE_PIN_SWCLK 18`, `PROBE_PIN_SWDIO 1`, no `PROBE_PIN_OFFSET`, no `PROBE_PIN_RESET`, product string "Debugprobe on RP2040 Pmod (CMSIS-DAP)" |
| `src/probe.pio` | The two pin directions are set one by one. The stock code sets two consecutive pins from `PROBE_PIN_OFFSET`, which needs SWDIO = SWCLK + 1. |
| `CMakeLists.txt` | `PICO_XOSC_STARTUP_DELAY_MULTIPLIER=64`, the value in the Pmod's own board file (the SDK default is 6). `PICO_DEFAULT_UART_TX_PIN=12` and `PICO_DEFAULT_UART_RX_PIN=13`: the SDK stdio UART otherwise sits on GPIO 0/1, and GPIO 1 is SWDIO. |

debugprobe has no hook for an external config header. `include/board_config.h` includes
`board_pico_config.h` whenever the SDK board is `pico`, so the pins are changed in that file.
`-DDEBUG_ON_PICO=ON` or `-DPICO_CONFIG_HEADER=...` on the `cmake` line change nothing.

```bash
git clone -b rp2040-pmod https://github.com/disdi/debugprobe
cd debugprobe && git submodule update --init --recursive
export PICO_SDK_PATH=/path/to/pico-sdk
cmake -S . -B build-pmod -DPICO_BOARD=pico
make -C build-pmod -j8
picotool info -a build-pmod/debugprobe_on_pico.uf2
```

`picotool` must report `18: PROBE SWCLK` and `1: PROBE SWDIO` before the image is flashed.

## Flash

Unplug the Pmod's USB cable, hold SW1, plug it back in, then:

```bash
picotool load -x build-pmod/debugprobe_on_pico.uf2
```

`lsusb` must then show `2e8a:000c` "Debugprobe on RP2040 Pmod (CMSIS-DAP)". The udev rule for the
Raspberry Pi Debug Probe covers it. `picotool load -f` does not find the running probe, so the
button is needed each time.

## Run

Both USB cables connected (Arty and Pmod). Load the bitstream, then:

```bash
openocd -f interface/cmsis-dap.cfg -c "transport select swd" -c "adapter speed 1000" \
        -f openocd/swdcap.cfg -f openocd/p1_check.tcl -f openocd/p2_check.tcl \
        -c init -c p1_check -c "p1_stress 2000" -c p2_check -c shutdown
```

## Limits

- `DAP_SWJ_Pins` does nothing on this firmware, so a tool that toggles or reads single probe pins
  needs another probe. `DAP_SWD_Sequence` works.
- With flying leads instead of a direct plug-in, GPIO 18 and GPIO 1 are J1 pins 7 and 12, in
  different columns. Not tried.

## Triage

- Does not enumerate as CMSIS-DAP: the firmware (still the UART image, or the oscillator did not
  start).
- Enumerates, then `cannot read IDR`: check with `picotool info -a` which pins the flashed image
  drives. An image with SWCLK/SWDIO on GPIO 16/17 lands on host Pmod pins 2 and 8; the probe then
  samples SWDIO as constant 0, because that FPGA pin is unused.
