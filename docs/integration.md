## Integrating swdcap into an FPGA design

swdcap is a target, not a probe. A CMSIS-DAP dongle (Pi Debug Probe, MCU-Link, any DAPLink) is the
master. The Pmod carries SWCLK, SWDIO and ground, plus VTREF for probes that sense it. The design
instantiates `SwdcapTop` and ties instrument ports to real signals. There is no probe firmware, no
OpenOCD fork, and no change to the board's JTAG or SPI configuration path.

**v0.1 scope:** the gateway, the ID window and EIO. The logic analyzer (ELA), Wishbone bridge
and UART are planned for later releases; their windows are reserved and return an error
(STICKYERR) until they are generated. Nothing is built yet; this guide describes the planned
interface.

### What the design does

1. Add `gen/SwdcapTop.v`. The rest of the project can stay Verilog, VHDL or LiteX; SpinalHDL is
   not needed to integrate.
2. Instantiate it next to the logic to be observed. FPGA configuration is unchanged; SWD is a
   second port.
3. Clock it. `clk` / `reset` is the debug clock that the instruments and the gateway's CDC run on,
   usually `sys_clk`. SWCLK clocks only the SWD PHY and DP. On FPGA that side has no reset input:
   start values come from bitstream initialisation, and line reset is the protocol reset. The
   silicon build (`swdAsyncReset = true`) also resets it from `reset`.
4. Put the SWDIO pad in the design. `SwdcapTop` exposes SWDIO as three signals, `swdio_i`,
   `swdio_o` and `swdio_oe`, and the design adds the vendor tristate buffer (below).
5. Tie every instrument input explicitly. Unconnected inputs are undriven: X in simulation and
   tool-dependent in synthesis. Instruments the design does not need are generated out (generator
   options), not left floating. The ID window's FEATURES bits report what was generated, not what
   is wired.
6. Constrain the two pads. SWCLK is a clock, asynchronous to the debug clock. Never place SWCLK and
   SWDIO on adjacent pins.
7. Load the bitstream the way the board already loads (Vivado, `openFPGALoader`, LiteX). Until that
   bitstream is running, the probe has nothing to talk to.

Port sketch (pseudocode until P1 fixes the exact instrument port names):

```verilog
SwdcapTop u_swdcap (
  .clk        (sys_clk),          // debug clock: instruments + gateway CDC
  .reset      (sys_rst),
  .swclk      (pmod_swclk),       // clock-capable pin
  .swdio_i    (swdio_i),          // from the pad
  .swdio_o    (swdio_o),          // to the pad
  .swdio_oe   (swdio_oe),         // 1 = target drives SWDIO
  .eio_in     (buttons),
  .eio_out    (leds)
  // after v0.1, only if generated:
  // ELA: ela_clk (may differ from clk), ela_probe
  // Wishbone master: wb_cyc, wb_stb, wb_we, wb_adr, wb_dat_w, wb_dat_r, wb_ack, wb_err
  // UART byte streams to the design: uart_tx_*, uart_rx_*
);
```

SWDIO pad, by vendor:

```verilog
// Xilinx 7-series
IOBUF u_swdio (.IO(pmod_swdio), .I(swdio_o), .O(swdio_i), .T(~swdio_oe));

// Lattice ECP5
BB    u_swdio (.B(pmod_swdio),  .I(swdio_o), .O(swdio_i), .T(~swdio_oe));
```

In LiteX, use a `TSTriple` on the platform pad and an `Instance("SwdcapTop", …)`.
`litex/swdcap_arty.py` is the reference wrapper.

The address map lives inside `SwdcapTop`. The design does not assign DMI addresses, and
`0x0000–0x007F` is reserved for a later Debug Module.

| Instrument | Release | DMI word | What a session can do |
|---|---|---|---|
| ID window | v0.1 | `0x0100` | Read magic, version, features and widths |
| EIO | v0.1 | `0x0200` | Drive and sample pins |
| ELA | later | ctrl `0x0300`, samples via `RD_POP` | Capture a window to a VCD |
| Wishbone bridge | later | `0x0400`: ADDR, WDATA, RDATA, CMD, STAT | Read or write one fabric-bus word |
| UART | later | `0x0500`, RX pops on read | Byte stream over the same two wires |

Register offsets inside each window are in [regmap.md](regmap.md), frozen for v0.1.

### Constraints

```tcl
# Xilinx (XDC). Arty reference: SWCLK = JB3 (D15), SWDIO = JB7 (J17)
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports pmod_swclk]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports pmod_swdio]
create_clock -name swclk -period 100.0 [get_ports pmod_swclk]   ;# 10 MHz, above the 4 MHz used
set_clock_groups -asynchronous -group [get_clocks swclk] -group [get_clocks -of_objects [get_pins -hier *u_swdcap*clk]]
```

```
# Lattice ECP5 (LPF)
FREQUENCY PORT "pmod_swclk" 10 MHz;
IOBUF PORT "pmod_swdio" PULLMODE=UP IO_TYPE=LVCMOS33;
```

### Arty reference wiring

| Signal | Pin | Note |
|---|---|---|
| SWCLK | JB3 (`D15`) | Clock-capable; `create_clock`, async to `sys_clk` |
| SWDIO | JB7 (`J17`) | `PULLUP` |
| GND | JB11 | |
| Second GND | JB5 | Harness wire from the probe's ground. It suppresses SWDIO→SWCLK crosstalk; it is not a constraint |
| VTREF | JB12 | MCU-Link only. Leave it open on the Pi Debug Probe (no VTREF pin) |

### What the host does

Any CMSIS-DAP probe uses the same config:

```tcl
source [find interface/cmsis-dap.cfg]
transport select swd
adapter speed 1000
source openocd/swdcap.cfg
init
```

Then run the procs through `-c` on the command line, the telnet port (4444) or the Tcl RPC port
(6666, used by the `swdcap` CLI):

```tcl
swdcap_rd 0x0100    ;# magic 0x43445753: bitstream is up
```

The `swdcap` CLI commands (`probe`, `eio-read` and `eio-write` in v0.1) are sequences of these
`dap apreg` transactions. Swapping the Pi Debug Probe for an MCU-Link does not change the Tcl.

- **Tested (the gateway, with a RISC-V Debug Module behind it):** CMSIS-DAP.
- **Should work, untested:** other OpenOCD adapters with raw SWD/DAP access (J-Link via the `jlink`
  driver, FTDI SWD, ST-Link in `dapdirect_swd` mode).
- **Will not work:** ST-Link in HLA mode.
- `mdw` and `dap info` do not apply: the gateway is a designer-AP, not a MEM-AP.

### What this replaces

One Pmod session covers jobs that otherwise need spare pins or a vendor JTAG USER chain. v0.1
covers the first; the other three come with later releases:

- **GPIO (v0.1).** `eio-read` / `eio-write` on whatever is tied to the EIO port.
- **Fabric capture.** Arm the small ELA and dump a VCD. 32-bit probes, depth 256 or 1024; not a
  full ILA.
- **Bus peek.** One outstanding Wishbone read or write. A bad target address sets STAT, not
  STICKYERR, so it does not wedge the DAP.
- **UART.** Bytes over the same two wires, for a design with no spare UART pin.

It does not program the FPGA. It does not debug a CPU unless a Debug Module is later placed at
`0x00–0x7F`. Configuration stays on the board's normal path.

### Security

Anyone with a probe on the Pmod gets EIO drive and, once the Wishbone bridge exists and is
generated, bus-master access to the fabric. Leave swdcap out of production bitstreams, or at
least generate it without the bridge.
