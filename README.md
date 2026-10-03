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

P0 (the register contract) is done. No RTL or host code yet.

Build check: `git submodule update --init` then `sbt test` (needs a JDK and sbt).

Order of work: simulation, then a Digilent Arty A7 with a Pmod SWD harness, then a Tiny Tapeout
(SKY130) wrapper once EIO works on both.

- [Plan](swdcap-plan.md)
- [Integration guide](docs/integration.md)
- [Register map](docs/regmap.md) (frozen for v0.1)

## Scope

- SWD slave only; the probe is the master.
- Not a MEM-AP and not RSDP.
- Not a CPU debugger. A RISC-V Debug Module may share the same DMI bus later.

## License

MIT. See [LICENSE](LICENSE).
