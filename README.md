# swdcap

Debug instruments over **SWD**: an fpgacapZero-style toolkit reached through two wires
(SWCLK + SWDIO) instead of JTAG.

**v0.1** is the SWD gateway, an ID window and EIO (drive and sample pins). A small logic
analyzer, a Wishbone bridge and a UART are planned for later releases.

The FPGA (or chip) is the SWD **target**. Any CMSIS-DAP probe is the master, driven by stock OpenOCD.

```
OpenOCD (dap apreg) + swdcap CLI
  -> CMSIS-DAP probe
  -> SW-DP + DMI gateway AP   (SpinalHDL spinal.lib.com.swd + SwdDmiGateway, unchanged)
  -> DMI bus -> ID · EIO      (v0.1)
             -> ELA · Wishbone bridge · UART   (later, reserved windows)
```

## Status

P0 (the register contract), P1 (gateway + ID window) and P2 (EIO) are done: in simulation, and on
a Digilent Arty A7 with an MCU-Link at 1 and 4 MHz. The v0.1 instruments are complete on FPGA.
The Tiny Tapeout wrapper is next.

Build and test: `git submodule update --init`, then `sbt test` (needs a JDK, sbt and Verilator).
`sim/run_openocd.sh` runs a real OpenOCD against the simulation; set `OPENOCD` to the binary.

Arty A7: `boards/arty/swdcap_arty.py --build --load` (needs LiteX, litex-boards and Vivado), then
the OpenOCD command in the [plan](swdcap-plan.md), section P1b. For EIO, add
`-f openocd/p2_check.tcl` and run `p2_check`, or use `swdcap_eio_read` / `swdcap_eio_write`.

Order of work: simulation, then a Digilent Arty A7 with a Pmod SWD harness, then a Tiny Tapeout
(SKY130) wrapper once EIO works on both.

- [Plan](swdcap-plan.md)
- [Integration guide](docs/integration.md)
- [Register map](docs/regmap.md) (frozen for v0.1)
- [RP2040 Pmod as the probe](docs/rp2040-pmod-probe.md) (plugs straight into the Arty, no harness)

## Scope

- SWD slave only; the probe is the master.
- Not a MEM-AP and not RSDP.
- Not a CPU debugger. A RISC-V Debug Module may share the same DMI bus later.

## License

MIT. See [LICENSE](LICENSE).
