# swdcap

Debug instruments over **SWD**: an fpgacapZero-style toolkit reached through two wires
(SWCLK + SWDIO) instead of JTAG.

**v0.1** is the SWD gateway, an ID window and EIO (drive and sample pins). A small logic
analyzer, a Wishbone bridge and a UART are planned for later releases.

The FPGA (or chip) is the SWD **target**. Any CMSIS-DAP probe is the master, driven by stock OpenOCD.

```
OpenOCD (dap apreg) + the procedures in openocd/swdcap.cfg
  -> CMSIS-DAP probe
  -> SW-DP + DMI gateway AP   (SpinalHDL spinal.lib.com.swd + SwdDmiGateway, unchanged)
  -> DMI bus -> ID · EIO      (v0.1)
             -> ELA · Wishbone bridge · UART   (later, reserved windows)
```

## Status

v0.1 is complete on FPGA and submitted for silicon.

- **Simulation and FPGA.** P0 (the register contract), P1 (gateway + ID window) and P2 (EIO) pass
  in simulation and on a Digilent Arty A7 at 1 and 4 MHz, with an MCU-Link and with an RP2040
  Pmod as the probe.
- **Silicon.** The same core, generated with a 10-bit DMI address and an asynchronous reset of
  the SWCLK domain, fits 1x2 SKY130 tiles and passes a gate-level test of the SWD protocol. The
  Tiny Tapeout project is a separate repository, <https://github.com/disdi/ttsky-swdcap>,
  submitted to shuttle `ttsky26d` on 2026-10-05.
- **Not written yet.** The `swdcap` command-line tool. Until then the host side is OpenOCD with
  the procedures in `openocd/swdcap.cfg`: `swdcap_probe`, `swdcap_rd` / `swdcap_wr`,
  `swdcap_eio_read` / `swdcap_eio_write`.

## Build and test

`git submodule update --init`, then `sbt test` (needs a JDK, sbt and Verilator).
`sim/run_openocd.sh` runs a real OpenOCD against the simulation; set `OPENOCD` to the binary.

Arty A7: `boards/arty/swdcap_arty.py --build --load` (needs LiteX, litex-boards and Vivado), then
the OpenOCD command in the [plan](swdcap-plan.md), section P1b. For EIO, add
`-f openocd/p2_check.tcl` and run `p2_check`, or use `swdcap_eio_read` / `swdcap_eio_write`.

Netlists: `gen/SwdcapTop.v` is the FPGA build (`sbt "runMain swdcap.SwdcapTopVerilog"`) and
`gen/silicon/SwdcapTop.v` the Tiny Tapeout one (`sbt "runMain swdcap.SwdcapTopSiliconVerilog"`).
A design instantiates either without SpinalHDL.

## Documents

- [Plan](swdcap-plan.md)
- [Integration guide](docs/integration.md)
- [Register map](docs/regmap.md) (frozen for v0.1)
- [RP2040 Pmod as the probe](docs/rp2040-pmod-probe.md) (plugs straight into the Arty, no harness)
- [Tiny Tapeout project](https://github.com/disdi/ttsky-swdcap) (wrapper, constraints, gate-level test)

## Scope

- SWD slave only; the probe is the master.
- Not a MEM-AP and not RSDP.
- Not a CPU debugger. A RISC-V Debug Module may share the same DMI bus later.

## License

MIT. See [LICENSE](LICENSE).
