# swdcap

FPGA debug instruments over **SWD**: an fpgacapZero-style toolkit (EIO, small logic
analyzer, bus bridge, UART) reached through two wires (SWCLK + SWDIO) instead of JTAG.

The FPGA is the SWD **target**. Any CMSIS-DAP probe is the master, driven by stock OpenOCD.

```
OpenOCD (dap apreg) + swdcap CLI
  -> CMSIS-DAP probe
  -> SW-DP + DMI gateway AP   (SpinalHDL spinal.lib.com.swd / DebugTransportModuleSwd, unchanged)
  -> DMI bus -> ID · EIO · ELA · bus bridge · UART
```

## Status

Planning. No RTL or host code yet. The first bring-up target is a Digilent Arty A7.

## Scope

- SWD slave only; the probe is the master.
- Not a MEM-AP and not RSDP.
- Not a CPU debugger. A RISC-V Debug Module may share the same DMI bus later.

## License

MIT. See [LICENSE](LICENSE).
