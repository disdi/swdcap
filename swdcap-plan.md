# swdcap — SWD fcapz plan

SWD analogue of fpgacapZero (<https://github.com/lcapossio/fpgacapZero>). The FPGA (or soft IP)
is the **target**, not the probe. A stock CMSIS-DAP probe and stock OpenOCD reach on-chip
instruments over two wires, with no JTAG TAP and no vendor BSCAN.

**v0.1 is the gateway plus an ID window and EIO.** A stock probe can read the magic and drive
the EIO pins. ELA, the Wishbone bridge and UART stay in the map as reserved windows, generated
out, and are not on the v0.1 exit bar. That core fits a Tiny Tapeout 1x2 tile: the area check
in phase PT hardened it at 67.8 % utilisation.

The transport is the **existing SWD DMI gateway, unchanged**: the same SW-DP and designer-AP
that carry the RISC-V DMI on VexRiscv / VexiiRiscv / ElemRV. swdcap puts instruments on its
DMI bus instead of, or next to, a Debug Module. The upstream components and the AP register map
are not modified; only the reset of the SWCLK domain differs between FPGA and silicon (see
**SWCLK-domain reset**).

```
PC — stock OpenOCD (`dap apreg`) + Python CLI over Tcl RPC
  │
CMSIS-DAP probe (SWD master: Pi Debug Probe, MCU-Link, RP2040 Pmod, any DAPLink)
  │  SWCLK + SWDIO + GND (+ VTREF from target 3V3)
  │
SWD transport ................. SpinalHDL dev components, unchanged
  │   SwdPhy + SwdDp            (spinal.lib.com.swd, #1966)              [SWCLK domain]
  │                             reset: BOOT on FPGA, async from rst_n on silicon
  │   SwdDmiGateway             AP_IDR / DMI_ADDR / DMI_DATA / POSTED_READ
  │   ccToggle CDC              one outstanding access, WAIT until done
  │
DebugBus(addressWidth = 16) ── DMI decoder                                [debug clock]
  ├── 0x0000–0x007F  reserved for a RISC-V DM (P7); reads 0 when absent
  ├── ID · EIO                                v0.1 (DebugBusSlaveFactory)
  └── 0x0300 · 0x0400 · 0x0500 · 0x8000       reserved; STICKYERR until generated
```

## Non-goals (v0.1)

- ELA, sample RAM, Wishbone bridge and UART in the v0.1 bitstream (generated out)
- A design that needs a RAM macro, or more than 1x2 SKY130 tiles
- SWCLK above 1 MHz on Tiny Tapeout in v0.1. 1 MHz is a conservative start; the ceiling is
  measured on silicon, not assumed
- Full fcapz-sized ILA
- Multi-drop SWD (DPv2 TARGETSEL)
- MEM-AP, ROM table, ADIv6. The gateway is a designer-AP, so stock `mdw` and `dap info` do not apply.
- Any change to the gateway RTL or its AP register map
- Secure debug / authentication
- Black Magic Probe as an instrument host. Its gateway support ([blackmagic#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322)) matches the AP_IDR but
  expects a DM.

## Reuse, not rewrite

Everything from the pins to the DMI bus already exists. It is merged upstream and
hardware-verified on a Digilent Arty A7 (Pi Debug Probe, MCU-Link, Black Magic Probe) and a
Machdyne Kopflos (ECP5):

| Piece | Source | What it already gives swdcap |
|---|---|---|
| `SwdPhy`, `SwdDp` | `spinal.lib.com.swd` ([SpinalHDL#1966](https://github.com/SpinalHDL/SpinalHDL/pull/1966)) | Line reset, turnaround, parity, ACK; DPIDR, CTRL/STAT, SELECT, RDBUFF/RESEND, ABORT, sticky errors, WAIT gating, posted reads |
| `SwdDmiGateway` | `spinal.lib.cpu.riscv.debug.DebugTransportModuleSwd` | Designer-AP, the CDC (`ccToggle`, BOOT-reset SWCLK domain), one outstanding DMI access, `DebugRsp.error` → STICKYERR |
| `DebugBus`, `DebugBusSlaveFactory` | `spinal.lib.cpu.riscv.debug.DebugInterfaces` | 32-bit word-addressed bus plus a register-file factory for the instruments |
| Raw-AP host procs | [`vexriscv_swd.cfg`](https://github.com/disdi/litex/tree/swd/litex/tools/debug/vexriscv_swd.cfg) (disdi/litex `swd`) | `dmi_read` / `dmi_write` over `dap apreg`, already proven on stock OpenOCD master |

**New work is only below `DebugBus`:** the decoder, the ID window and EIO. The deliverable is
generated Verilog (`SwdcapTop`), so users do not need SpinalHDL, plus a LiteX wrapper for Arty
bring-up: LiteX-Boards' stock `digilent_arty` target with two added SWD pads.

`SwdcapTop` = `SwdPhyDp` + `SwdDmiGateway` + decoder + ID + EIO. It assembles the same upstream
pieces as `DebugTransportModuleSwd`, so that it can choose the SWCLK-domain reset (below).
Generator config; the defaults are the FPGA build:

```scala
case class SwdcapConfig(
  addressWidth:  Int     = 16,     // Tiny Tapeout wrapper: 10
  swdAsyncReset: Boolean = false,  // Tiny Tapeout wrapper: true
  withEio:  Boolean = true,
  withEla:  Boolean = false,
  withWb:   Boolean = false,
  withUart: Boolean = false,
  eioInWidth:   Int  = 8,
  eioOutWidth:  Int  = 8,
  scratchWidth: Int  = 32,
  debugClkHz:   Long = 0         // reported in DEBUG_CLK_HZ; 0 = unknown
)
```

`FEATURES` bit 0 is set. Bits 1–4 are zero unless a later wrapper turns that option on.
`addressWidth` is an existing parameter, not an RTL change. The 16-bit DMI word address gives a
256 KiB map. That is within the Debug Spec §3.1.1 range of 7–32 bits, so a DM can share the bus
later.

### SWCLK-domain reset

Upstream runs the SWD side (`SwdPhy`, `SwdDp`, the gateway's SWCLK half and its CDC toggles) in a
**BOOT-reset** clock domain: registers get their start values from FPGA bitstream initialisation,
because the two-wire interface has no reset pin.

- **FPGA (`swdAsyncReset = false`):** unchanged BOOT reset, as verified on the Arty and Kopflos.
- **Silicon (`swdAsyncReset = true`):** SKY130 flops power up undefined, and an SWD line reset
  only resets the PHY state machine. It does not clear the DP's `apBusy`, sticky flags or
  `SELECT`, the gateway's `dmiPending`, or the CDC toggles. So the SWCLK domain gets an
  asynchronous reset from the chip reset (`rst_n`). SWCLK is stopped at power-up, so releasing
  that reset is safe. The Tiny Tapeout wrapper passes `rst_n` through a two-flop synchroniser
  first: the reset still asserts at once, and its release is aligned to `clk`, so the debug
  clock domain leaves reset on one edge.
- This needs no upstream change: `SwdDmiGateway` takes the SWD clock domain as a parameter, and
  `SwdPhyDp` runs in whichever clock domain its parent places it in. `DebugTransportModuleSwd` itself hard-wires the BOOT
  domain, which is why `SwdcapTop` assembles the pieces instead of instantiating it.
- The host must still send a line reset after the chip leaves reset, as on FPGA.

## Gateway contract, as it is

AP register map (`dap apreg <ap> <offset>`):

| Offset | Register | Behaviour |
|---|---|---|
| `0x00` | AP_IDR | RO `0x74726976` |
| `0x04` | DMI_ADDR | R/W, `addressWidth` bits, **word** address. Persists across accesses |
| `0x08` | DMI_DATA | Read or write performs one `DebugBus` access at DMI_ADDR. No autoincrement |
| `0x0C` | POSTED_READ | RO, last DMI read result |

Properties swdcap inherits and must design around:

- **Only A[3:2] is decoded.** APSEL and APBANKSEL are ignored, so every AP number and bank
  aliases the same four registers. `dap info` reads `0xFC`, which aliases POSTED_READ, so it
  prints garbage. Use the AP_IDR check in the P1 script instead.
- **No address autoincrement.** A random-access word costs one DMI_ADDR write and one
  DMI_DATA access. A register that **pops on read** costs one DMI_DATA read per word, because
  DMI_ADDR stays put. v0.1 has no pop port; ELA and UART RX will, when generated.
- **CDC is already solved.** `SwdDp` answers WAIT while the crossed access is pending, and the
  host's retry supplies the SWCLK edges. Instruments sit in the `DebugBus` (debug clock) domain.
  Only an instrument that samples on another clock (the ELA, not in v0.1) needs its own crossing.
- **Errors.** A `DebugRsp.error` from the decoder → STICKYERR, which OpenOCD clears via ABORT.
  An unmapped address returns an error, except the reserved DM range (below).
- **Tool identification.** The OpenOCD gateway backend ([disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway)) and the BMP support
  ([blackmagic#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322)) recognise
  `0x74726976` and look for a DM at DMI `0x00–0x7F`; the backend fixes `abits` at 7. With no DM,
  that range reads 0, and `dmstatus.version = 0` means "no Debug Module present" (Debug Spec
  §3.1.14.1), so those tools stop cleanly instead of misreading instruments.

## DMI memory map (word addresses, `addressWidth = 16`)

| DMI word | Byte equiv. | Window | Notes |
|---|---|---|---|
| `0x0000–0x007F` | `0x0_0000` | DM reserved | Reads 0, writes ignored, no error. A DM goes here in P7 |
| `0x0100` | `0x0_0400` | ID | Magic, version, features, clock, widths, scratch |
| `0x0200` | `0x0_0800` | EIO | IN (`0x0200`), OUT (`0x0201`). `0x0202` is held for a later output-enable register; the widths are in the ID window |
| `0x0300` | `0x0_0C00` | ELA ctrl | Reserved. STICKYERR until generated (after v0.1) |
| `0x0400` | `0x0_1000` | Bus bridge | Reserved. STICKYERR until generated (after v0.1) |
| `0x0500` | `0x0_1400` | UART | Reserved. STICKYERR until generated (after v0.1) |
| `0x8000–0xFFFF` | `0x2_0000` | ELA sample RAM | Reserved. Does not fit a TT tile; FPGA-only later |

### ID window (frozen in P0; full contract in [docs/regmap.md](docs/regmap.md))

| Word | Register | Value |
|---|---|---|
| `0x0100` | MAGIC | `0x4344_5753` (`"SWDC"`, little-endian bytes) |
| `0x0101` | VERSION | `major[31:16] minor[15:8] patch[7:0]` |
| `0x0102` | FEATURES | bit 0 EIO (set in v0.1), 1 ELA, 2 UART, 3 BUS_WB, 4 BUS_AXI, 5 DM present |
| `0x0103` | DEBUG_CLK_HZ | Instrument (DebugBus) clock |
| `0x0104` | EIO_WIDTH | `out[15:8]`, `in[7:0]`: number of EIO output and input bits (TT: 8 out, 8 in) |
| `0x0105` | ELA_WIDTH | Probe width (bits) |
| `0x0106` | ELA_DEPTH | Samples |
| `0x0107` | SCRATCH | R/W, reset `0` |

The host reads FEATURES and the widths, and never hard-codes them. It can also read the
DMI_ADDR width by writing `0xFFFFFFFF` to AP `0x04` and reading it back.

## Pinout

The Arty bring-up reuses the existing **JB SWD harness**, so a known-good reference bitstream for
that harness can check the rig before every bring-up:

| Signal | Arty | Notes |
|---|---|---|
| SWCLK | JB3 (D15) | MRCC, so the clock reaches the global network |
| SWDIO | JB7 (J17) | Pull-up in the XDC; **not** JB4 (C15 is D15's differential partner, crosstalk) |
| GND | JB11 | |
| GND (second) | JB5 ← breakout JP2.3 | Required. Without it the DP is double-clocked |
| VTREF | JB12 (3V3) | **Target supplies it, the probe senses it.** MCU-Link needs it wired. The Pi Debug Probe has no VTREF pin; leave it open |

A Pmod TPH2 in the SWD path works on the Arty: the known-good reference bitstream passed its
full check, including the GDB lane, through one on 2026-10-03 (MCU-Link). An earlier TPH2
module or its leads passed no signal at all, so re-run the reference check after inserting one.
On the Arty the SWDIO pull-up is the FPGA's internal one (XDC), so the TPH2 needs no resistor
there. nRESET is not used in v0.1 on any board.

**RP2040 Pmod as the probe.** A ControlPaths RP2040 Pmod running a patched `debugprobe` plugs
straight into JB and replaces the MCU-Link, the breakout, the leads and the TPH2. It drives SWCLK
on Pmod pin 3 and SWDIO on pin 7, the same pins as the harness, so the bitstream does not change.
It has no VTREF pin. Verified 2026-10-04 on the Arty A7-35T with the normal build: `p1_check`,
`p1_stress 2000` and `p2_check` pass at 1 and 4 MHz. Firmware (branch `rp2040-pmod` of
<https://github.com/disdi/debugprobe>), pin map and flashing:
[docs/rp2040-pmod-probe.md](docs/rp2040-pmod-probe.md). Not tried on the Tiny Tapeout demo board.

**Tiny Tapeout (v0.1 silicon target; submitted to shuttle `ttsky26d` on 2026-10-05).** Same core, in 1x2 SKY130 tiles. ELA, Wishbone and
UART generated out; `addressWidth = 10`, `swdAsyncReset = true`. Probe at 1 MHz to start. The mux
round trip is about 20 ns, which is small against the 125 ns half period at 4 MHz, so the real
ceiling is to be measured. Select the project before probing: an inactive tile has its `uio`
tristate disabled.

The SWD port sits on the **bidirectional Pmod header, on the same Pmod pins as the Arty JB
harness** (pin 3 SWCLK, pin 7 SWDIO, pins 5 and 11 GND, pin 12 VTREF). The MCU-Link + breakout +
TPH2 assembly verified on the Arty then plugs into the demo board unchanged, both grounds
included, and SWCLK and SWDIO stay on different rows.

| Port | Pin | Note |
|---|---|---|
| `swclk` | `uio_in[2]` (Pmod pin 3) | Probe-driven, `uio_oe[2] = 0`. Not the dedicated `clk` (demo-board PWM). Needs its own clock definition in the SDC |
| `swdio_i/o/oe` | `uio_in[4]` / `uio_out[4]` / `uio_oe[4]` (Pmod pin 7) | **External pull-up required**: `uio` has no internal one |
| debug clock | `clk` | Must be running, or every DMI access returns WAIT |
| debug reset | `rst_n` | Active-low. Also the async reset of the SWCLK domain |
| EIO in | `ui_in[7:0]` | 8 bits |
| EIO out | `uo_out[7:0]` | 8 bits |
| unused | `uio[0]`, `uio[1]`, `uio[3]`, `uio[5]`, `uio[6]`, `uio[7]` | `uio_oe = 0`, `uio_out = 0` |

**Confirmed 2026-10-05** against the layout of the current demo board ("Tiny Tapeout Demoboard
v3", rev 3.3, in <https://github.com/TinyTapeout/tt-demo-pcb>). The bidirectional Pmod is J15:

| J15 pin | Net |
|---|---|
| 1, 2, 3, 4 | `uio[0]`, `uio[1]`, `uio[2]`, `uio[3]` |
| 5, 11 | GND |
| 6, 12 | 3.3 V |
| 7, 8, 9, 10 | `uio[4]`, `uio[5]`, `uio[6]`, `uio[7]` |

So SWCLK is on pin 3 and SWDIO on pin 7, as on the Arty JB harness. Neither net has a pull
resistor on the board. `uio[2]` is also on pin 3 of the 3-pin header J6. Earlier demo-board
revisions were not checked.

The demo board's controller, an RP2350 on this revision, also connects to `uio`: GPIO27 is
`uio[2]` and GPIO29 is `uio[4]`. It must leave both undriven while an external probe is attached
(`uio_oe_pico` bits 2 and 4 clear).

**MCU-Link on the demo board.** CMSIS-DAP firmware. The board is USB-powered, so the probe must not
power it; if your MCU-Link has a target-power option, leave it off. Both sides are 3.3 V once
VTREF is tied to the board rail, so no level shifter is needed.

| MCU-Link 10-pin | Signal | Bidirectional Pmod header |
|---|---|---|
| 1 | VTREF | Pin 12, 3.3 V. The probe senses it; open VTREF means no SWD |
| 2 | SWDIO | Pin 7, `uio[4]`; same node as the pull-up |
| 4 | SWCLK | Pin 3, `uio[2]`; not the dedicated `clk` |
| 3 and 5 | GND | Pins 5 and 11. Use both |
| 10 | nRESET | Leave open |

The pull-up is 10 kΩ to 100 kΩ from the SWDIO test point of the TPH2 to the header's 3.3 V. It is
not in series with SWDIO. The TPH2 itself is verified on the Arty; confirm it on the demo board
with the first probe.

Bring-up order on the demo board:

1. Select the project.
2. Start `clk`.
3. Pulse `rst_n` low, then release it.
4. `adapter speed 1000`, then `swdcap probe`: expect `AP_IDR 0x74726976` and magic `0x43445753`.
5. `swdcap eio-write <value>`, then `swdcap eio-read`.

With `clk` stopped, DPIDR and AP_IDR still read, but every DMI access returns WAIT.

A Black Magic Probe finds the gateway but no Debug Module, so it reports no target and cannot
reach EIO.

With `addressWidth = 10`, DMI_ADDR holds only 10 bits, so `0x0400` and above alias into
`0x0000–0x03FF` instead of returning STICKYERR. The host reads the DMI_ADDR width (write
`0xFFFFFFFF` to AP `0x04`, read it back) and refuses addresses beyond it.

**Machdyne Kopflos port (after v0.1):** reuse the harness already verified there with ElemRV, on
PMOD1 (SWCLK J3, SWDIO K2). PMOD2 M5/T4 is taken by the UART console (Machdyne Steg).

## Phases

### P0 — contract

**Done 2026-10-03.** The contract is frozen in [docs/regmap.md](docs/regmap.md) and
`hw/spinal/swdcap/SwdcapRegs.scala`; the generator options are in `SwdcapConfig.scala`, with unit
tests in `hw/test/`. `sbt test` builds against the pinned SpinalHDL submodule.

Decisions taken while freezing:

- EIO has two registers, IN and OUT. There is no output-enable register in v0.1, because
  `eio_out` is a plain output port; `0x0202` is held for one.
- Unmapped words inside a mapped window return an error, like the reserved windows. A write to a
  read-only register is ignored without an error.
- `0x0080–0x00FF` is unmapped (error). Only `0x0000–0x007F` is the read-zero DM range.
- `DEBUG_CLK_HZ` is a generation-time constant, and `0` means unknown.
- `eioInWidth`, `eioOutWidth`, `scratchWidth` and `debugClkHz` are generator options.

- Freeze the ID window, FEATURES and the DMI map above. `0x0300`, `0x0400`, `0x0500` and
  `0x8000` stay reserved and return STICKYERR.
- **DPIDR / AP_IDR:** inherited unchanged from the gateway, `0x0BA11AAB` / `0x74726976`, so the
  OpenOCD gateway backend and the Black Magic Probe keep identifying the transport. The designer
  code is a documented squat (JEP106 continuation 10, identity `0x55`, Facebook Inc), accepted in
  [blackmagic#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322). Any change
  belongs upstream in SpinalHDL.
- Generator default: `withEio = true`, `withEla = withWb = withUart = false`,
  `addressWidth = 16`, `swdAsyncReset = false`. The Tiny Tapeout wrapper overrides the last two.
- Wishbone, not AXI, if the bus bridge is generated later.

### P1 — gateway + ID window

**P1a sim. Done 2026-10-03.** `SwdcapTop` with the ID window only (EIO was added in P2),
under Verilator, in two shapes: `fpga` (16-bit DMI address, BOOT-reset SWCLK domain) and `silicon`
(10-bit, SWCLK domain reset from the debug reset).

- **SpinalSim, `sbt test`:** the upstream SWD host model drives the real wire protocol. Per shape:
  identify + ID window + SCRATCH with the debug clock slower than, faster than and much slower
  than SWCLK; DMI_ADDR width; the DM range; read-only registers; unmapped and not-generated
  windows returning an error with ABORT recovery (including `0x0300` at 10 bits); FAULT while
  sticky; line reset mid-session. `silicon` also checks that the debug reset clears the SWD side
  and that addresses beyond 10 bits alias.
- **Real OpenOCD, `sim/run_openocd.sh [fpga|silicon]`:** stock OpenOCD over `remote_bitbang`
  against the same simulation, running `openocd/swdcap.cfg` and `sim/p1_check.tcl`. The server is
  `SwdRemoteBitbang` in this repo; it speaks the same protocol as the LiteX `swdremote` module
  used for the RISC-V gateway, so the repo needs no LiteX.
- `gen/SwdcapTop.v` is the `fpga` shape: about 530 flops without EIO at the time of P1.

**P1b Arty. Done 2026-10-03** on an Arty A7-35T with the MCU-Link (CMSIS-DAP) on the JB harness,
with a Pmod TPH2 in the SWD path.

- The known-good reference bitstream for the harness passed first (10 of 10), so the rig was
  healthy.
- `boards/arty/swdcap_arty.py --build --load`: a minimal LiteX SoC (no CPU) around
  `gen/SwdcapTop.v`. Timing met (WNS 1.19 ns at 100 MHz); `SwdcapTop` uses 210 LUTs and 503
  flip-flops.
- Check, with stock OpenOCD:

```
openocd -f interface/cmsis-dap.cfg -c "transport select swd" -c "adapter speed 1000" \
        -f openocd/swdcap.cfg -f openocd/p1_check.tcl \
        -c init -c p1_check -c "p1_stress 2000" -c shutdown
```

| Debug clock | SWCLK | `p1_check` | `p1_stress 2000` |
|---|---|---|---|
| 100 MHz (above SWCLK) | 1 MHz | pass | pass |
| 100 MHz (above SWCLK) | 4 MHz | pass | pass |
| 390.6 kHz (`--debug-clk-div 256`, below SWCLK) | 1 MHz | pass | pass |
| 390.6 kHz (`--debug-clk-div 256`, below SWCLK) | 4 MHz | pass | pass |

`p1_check` identifies the target (DPIDR, AP_IDR, MAGIC, VERSION 0.1.0, FEATURES 0, DMI_ADDR 16
bits), exercises SCRATCH, reads `dmstatus` as 0, and checks that `0x0300` errors on read and write
and that the link recovers. `p1_stress` is 2000 SCRATCH write / read-back pairs with changing
data. The `silicon` shape (10-bit, async reset) is verified in simulation only so far; it runs on
the Arty in PT.

**Exit (all met in sim and on the Arty):**
- DPIDR, AP_IDR and MAGIC stable.
- Scratch read/write stable at 1 MHz. 4 MHz is an Arty-only stretch; Tiny Tapeout stays at 1 MHz.
- An access to `0x0300` sets STICKYERR, and the next access after ABORT succeeds. This must also
  hold with `addressWidth = 10`, where `0x0300` is addressable: the decoder errors on a window
  that is not generated, and the host trusts FEATURES, not the DMI_ADDR read-back.
- Repeat with a debug clock below **and** above SWCLK. The gateway CDC is proven for the DM's
  clock ratios, not for arbitrary ones.

### P2 — EIO

Last v0.1 instrument phase (PT follows for silicon). Same job as fcapz `eio-read` / `eio-write`.

**Done 2026-10-03**, in simulation and on the Arty A7-35T (MCU-Link, Pmod TPH2 in the SWD path).

- **RTL.** `Eio.scala`: EIO_IN (`0x0200`, the `eio_in` port through a two-flop synchroniser) and
  EIO_OUT (`0x0201`, drives `eio_out`, reset 0). `SwdcapTop` gains the `eio_in` / `eio_out` ports
  and `FEATURES` bit 0 is set. The default netlist `gen/SwdcapTop.v` is now 8 in / 8 out.
- **Simulation, `sbt test` (57 tests).** EIO_OUT drives the port and reads back; EIO_IN samples
  the port; a write to EIO_IN is ignored without an error; `0x0202` errors; the debug reset
  clears EIO_OUT. Run on four shapes: `fpga`, `silicon`, no EIO (`0x0200` errors, FEATURES 0)
  and uneven widths (4 in / 12 out; bits above each width read 0).
- **Real OpenOCD in simulation.** `sim/run_openocd.sh` now runs `p1_check` and
  `p2_check loopback` (the simulation loops `eio_out` back to `eio_in`); both shapes pass.
- **Host.** `swdcap_eio_read` / `swdcap_eio_write` in `openocd/swdcap.cfg`; `openocd/p2_check.tcl`
  has `p2_check` and `p2_walk` (walks one lit output across the LEDs).
- **Arty.** The reference bitstream passed first (10 of 10). `eio_out[3:0]` drive LD4–LD7 and
  `eio_out[7:4]` the green of LD0–LD3; `eio_in[3:0]` are BTN0–BTN3 and `eio_in[7:4]` SW0–SW3.
  Timing met (WNS 1.20 ns); `SwdcapTop` is 199 LUTs and 535 flip-flops.

| Arty build | SWCLK | `p1_check` | `p2_check` | `p1_stress 500` |
|---|---|---|---|---|
| `--eio-loopback` (`eio_in` = `eio_out`) | 1 MHz | pass | pass, loopback mode | pass |
| `--eio-loopback` | 4 MHz | pass | pass, loopback mode | pass |
| normal (LEDs, buttons, switches) | 1 MHz | pass | pass | pass |
| normal | 4 MHz | pass | pass | pass |

On the normal build EIO_IN read `0xF0`: the four switches on, no button pressed. The LED walk and
the button response are for a person at the board to confirm; the loopback build is what proves
both directions without one.

### PT — Tiny Tapeout wrapper and hardening (v0.1)

**Entry gate:** PT starts only after EIO (P2) works in simulation **and** on the Arty with the Pmod
harness. No Tiny Tapeout work, including the area check, runs before that.

- **Area check. Done 2026-10-05: the core fits 1x2 SKY130 tiles, with no trims.** The silicon
  netlist (`SwdcapConfig.tinyTapeout`) was hardened with the Tiny Tapeout local flow
  (LibreLane 3.0.3, `sky130A`, the `ttsky26d` template) behind a throwaway `tt_um_*` wrapper with
  the pin map above. Result and commands: **Area check result** below.
- **Trims, if a later change needs the space.** None are needed now, but the margin is small:
  see the hardening notes under **Tiny Tapeout repository and gate-level result**. `addressWidth = 10` is
  already the wrapper default and there is no EIO output-enable register. In this order: fewer
  hold buffers (they are about a quarter of the placed cell area), a narrower `scratchWidth`,
  then narrower EIO widths.
- **Wrapper. Done 2026-10-05**, in the Tiny Tapeout repository (**Repo layout** below):
  `tt_um_disdi_swdcap` with the pin map above, `info.yaml` for 1x2 tiles, unused `uio` tied off.
- **Pull-up rehearsal.** On the Arty, turn off the internal SWDIO pull-up in the XDC and fit the
  same 10 kΩ–100 kΩ resistor on the TPH2's SWDIO test point. That is the electrical setup the
  chip will have.
- **Reset.** `swdAsyncReset = true`; see **SWCLK-domain reset**. Re-run the P1/P2 checks with this
  variant in simulation and on the Arty (a button as `rst_n`) before hardening, so the
  configuration that goes to silicon has run on hardware.
- **Constraints.** Two clocks: `clk` and SWCLK on `uio_in[2]`, asynchronous to each other. The
  flow takes a custom SDC through `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE` in `src/config.json`,
  with `CLOCK_PORT` left at `clk`; clock tree synthesis then builds a tree on `uio_in[2]` as
  well (confirmed in the area check). The recipe in the Tiny Tapeout FAQ is for the older
  OpenLane and is not needed. In the Tiny Tapeout repository SWDIO is timed against SWCLK, and
  EIO and `rst_n` against `clk`; the delay values are still estimates, not measured board
  figures.
- **Gate-level simulation. Done 2026-10-05.** A cocotb test with an SWD host model drives the
  wire protocol at 1 MHz against a free-running 50 MHz `clk`. It passes on the RTL and on the
  hardened netlist. Result: **Tiny Tapeout repository and gate-level result** below.
- **Repo layout. Decided 2026-10-05: a separate repository**,
  <https://github.com/disdi/ttsky-swdcap>, made from `ttsky-verilog-template`. It carries a copy
  of `gen/silicon/SwdcapTop.v`, so its GitHub Actions need no JVM and harden the same file that
  ran on the Arty. The netlist is never edited there: regenerate it here and copy it.
- **Shuttle. Submitted 2026-10-05 to `ttsky26d`** (SKY130),
  <https://app.tinytapeout.com/shuttles/ttsky26d>, as a 1x2 project from
  <https://github.com/disdi/ttsky-swdcap>. That repository's head was `7a93353` at the time: the
  wrapper with the reset synchroniser, hardened without slew or capacitance violations, with
  every GitHub Actions job passing. A later push there changes the chip only if the project is
  submitted again before the shuttle closes.

#### Area check result (2026-10-05)

One full LibreLane run, synthesis through DRC and LVS, on 1x2 tiles (die 161 x 225.76 um).
Constraints: `clk` at 50 MHz, SWCLK at 4 MHz, asynchronous clock groups, placeholder I/O delays.

| Item | Value |
|---|---|
| Utilisation (`tt_tool.py --print-stats`) | 67.8 % |
| Flip-flops | 513 |
| Cell area: flip-flops / logic / hold and timing buffers / clock tree | 11,740 / 8,710 / 7,170 / 1,870 um2 |
| Magic DRC, LVS, antenna violations | 0, 0, 0 |
| Setup and hold | met in all corners; `clk` fmax 74 MHz in the slow corner |
| Max slew / max capacitance, slow corner only | 10 / 1, on one net, about 30 ps over a 1.5 ns limit |

One tile cannot hold it: flip-flops and logic alone are about 20,400 um2. The wrapper and the SDC
of this run were throwaway, so the numbers are a fit check, not sign-off. No gate-level
simulation was run.

To run it again, set up the flow once as in the Tiny Tapeout local-hardening guide
(<https://tinytapeout.com/guides/local-hardening/>): Python 3.11 or newer, Docker, a project made
from `ttsky-verilog-template` with `tt-support-tools` cloned into it as `tt/`, and
`pip install librelane==3.0.3`. Then, with `PDK_ROOT` set to the directory for the PDK:

```bash
sbt "runMain swdcap.SwdcapTopSiliconVerilog"        # in this repo: gen/silicon/SwdcapTop.v
```

Copy that netlist and the `tt_um_*` wrapper into the project's `src/`, list both under
`source_files` in `info.yaml`, set `tiles: "1x2"`, and in the project directory:

```bash
export PDK=sky130A LIBRELANE_TAG=3.0.3
./tt/tt_tool.py --create-user-config
./tt/tt_tool.py --harden
./tt/tt_tool.py --print-warnings
./tt/tt_tool.py --print-stats
```

The first `--harden` downloads the PDK and the LibreLane Docker image.

#### Tiny Tapeout repository and gate-level result (2026-10-05)

<https://github.com/disdi/ttsky-swdcap>:

| File | |
|---|---|
| `src/SwdcapTop.v` | copy of `gen/silicon/SwdcapTop.v` from this repository |
| `src/tt_um_disdi_swdcap.v` | wrapper: SWCLK `uio[2]`, SWDIO `uio[4]`, EIO in `ui_in`, EIO out `uo_out`, two-flop reset synchroniser on `rst_n` |
| `src/project.sdc`, `src/config.json` | the two clocks, and the two lines that pass the SDC to LibreLane |
| `test/test.py` | cocotb SWD host model and five tests |
| `info.yaml`, `docs/info.md` | 1x2 tiles, pinout, registers, bring-up steps |

The test, each case after a reset pulse and a line reset:

| Test | Checks |
|---|---|
| `test_identify` | DPIDR, AP_IDR, MAGIC, VERSION, FEATURES, EIO_WIDTH, DMI_ADDR 10 bits, `dmstatus` reads 0 |
| `test_scratch` | SCRATCH resets to 0 and reads back four patterns |
| `test_eio` | EIO_OUT drives `uo_out`; EIO_IN reads `ui_in`; a write to EIO_IN is ignored without an error |
| `test_error_and_abort` | read and write of `0x0300` set STICKYERR; ABORT clears it; MAGIC reads again |
| `test_reset_clears_both_domains` | `rst_n` clears STICKYERR and DMI_ADDR (SWCLK domain) and SCRATCH and EIO_OUT (debug domain) |

| Run | Result |
|---|---|
| RTL, Icarus Verilog | 5 of 5 pass |
| Gate level: the hardened netlist with the SKY130 functional cell models | 5 of 5 pass |
| GitHub Actions on the first push | `test`, `docs`, `gds`, `precheck` and `gl_test` pass |
| Hardening in that repository, first version | 67.8 % utilisation; DRC, LVS and antenna clean; setup and hold met; 10 max-slew and 1 max-capacitance violations in the slow corner |
| Hardening in that repository, with the reset synchroniser and the settings below | 69.0 % utilisation, 515 flip-flops, 430 hold buffers; DRC, LVS and antenna clean; setup and hold met (worst hold slack 0.05 ns); no max-slew or max-capacitance violations; test 5 of 5 on the RTL and on the netlist |

In the gate-level run every flip-flop starts undefined, so a flop that `rst_n` does not reach
would show up as an undefined value on SWDIO or `uo_out` and fail the test. The run uses unit
delays, not back-annotated timing, so it checks function and reset, not speed.

Hardening notes (2026-10-05). Two settings in `src/config.json` differ from the template, and
both came out of failed runs:

- **`PL_RESIZER_HOLD_SLACK_MARGIN` is 0.05, not 0.1.** With the reset synchroniser added and
  the margin left at 0.1, detailed placement fails: the hold buffers no longer fit in 1x2
  tiles. At 0.05 there are 430 hold buffers where the first version had 610, and hold is met in
  every corner on top of 0.25 ns of clock uncertainty.
- **`DESIGN_REPAIR_MAX_SLEW_PCT` and `DESIGN_REPAIR_MAX_CAP_PCT` are 40, not 20.** The repair
  runs in the typical corner before routing, and later steps add load. A margin of 30 and a
  repair pass after global routing (`RUN_POST_GRT_DESIGN_REPAIR`) each left 11 max-slew
  violations in the slow corner; 40 left none.

The result depends on these tuned margins. A larger netlist can bring back the placement
failure or a marginal slew violation, so harden again after every netlist change. The hold
buffers remain the first place to recover area.

Still open from this phase: a pull on SWCLK at the target (it floats when the probe is idle),
and the external pull-up rehearsal with a probe that has no pull-up of its own. Both are
board-level and can be settled before the chips return.

### P3 — ELA, small (after v0.1, generated out)

First step: remove `withEla` from the v0.1 guard in `SwdcapConfig` (`require(!withEla && …)`).
P4 and P5 do the same for `withWb` and `withUart`.

- 32-bit probes, depth 256 or 1024. The sample clock may differ from the debug clock, so the
  crossing is internal to the ELA.
- Trigger: value + mask, one comparator.
- Status: idle / armed / triggered / done.
- Readout: write `RD_PTR`, set DMI_ADDR to `RD_POP` once, then read DMI_DATA N times. One AP
  read per sample instead of two.

### P4 — bus bridge (after v0.1, generated out)

- Indirect Wishbone master, one outstanding transaction. Write ADDR (and WDATA), write CMD =
  read/write, poll STAT, read RDATA. Wishbone ERR → STAT error bit, not STICKYERR, so a bad
  target address does not wedge the DAP.
- AXI4-Lite is a later variant (FEATURES bit 4).

### P5 — UART (after v0.1, generated out)

- TX/RX FIFO, status bits, BAUD_DIV. RX is a pop port.
- Replaces EJTAG-UART for designs with no spare UART pin.

### P6 — host

- **P6a**: `openocd/swdcap.cfg` in tree: the P1b DAP setup plus `swdcap_rd` / `swdcap_wr`.
  Stock OpenOCD master; no `riscv` or `mem_ap` target. `swdcap_pop` arrives with the ELA.
- **P6b**: `swdcap` Python CLI over the OpenOCD Tcl RPC port (6666). v0.1 verbs:
  - `probe` (AP_IDR / magic / version / features / widths / DMI_ADDR width)
  - `eio-read` / `eio-write`
- `ela-arm`, `ela-dump`, `bus-read` and `uart` are wired when those generator options exist,
  not in v0.1.

### P7 — RISC-V DM on the same bus (after v0.1, optional)

- Put a VexRiscv/VexiiRiscv `DebugModule` at DMI `0x00–0x7F` behind the same decoder; set
  FEATURES bit 5.
- The `vexriscv-gateway` OpenOCD `riscv` target (abits 7) and the BMP support then debug
  the CPU **unchanged**, while the instruments stay reachable through `dap apreg` above `0x7F`.
- Check how OpenOCD's DM scan (`nextdm`) and BMP behave with a DMI_ADDR wider than 7 bits before
  claiming this.
- Any conformance statement must read "RISC-V Debug Specification, **with custom DTM**".

## Host contract

Any CMSIS-DAP probe is the SWD master. OpenOCD is stock master, using raw AP access only:

```
source [find interface/cmsis-dap.cfg]
transport select swd
adapter speed 1000
source openocd/swdcap.cfg            ;# swd newdap / dap create / swdcap_rd / swdcap_wr
```
## Folder structure

```
swdcap/
  README.md                       pitch, scope, Arty wiring table (incl. JB5 second GND, VTREF)
  LICENSE                         MIT
  build.sbt, project/             sbt build against SpinalHDL from source (SPINALHDL_PATH overrides)
  ext/SpinalHDL                   submodule pinned to 90b7d8eee (#1966, spinal.lib.com.swd)
  hw/spinal/swdcap/
    SwdcapTop.scala          P1   SwdPhyDp + SwdDmiGateway (selectable SWCLK reset) + DMI
                                  decoder; decoder also answers the DM-reserved 0x0000-0x007F
                                  with 0
    RegWindow.scala          P1   register port between the decoder and one 256-word window
    IdWindow.scala           P1   0x0100: magic, version, features, widths; scratch at 0x0107
    Eio.scala                P2   0x0200
    SwdcapRegs.scala         P0   frozen addresses and constants (mirror of docs/regmap.md)
    SwdcapConfig.scala       P0   addressWidth 16, swdAsyncReset false, withEio true;
                                  withEla / withWb / withUart default false
    # after v0.1, not in the v0.1 tree:
    # Ela.scala              P3   ctrl 0x0300, sample RAM 0x8000
    # WbBridge.scala         P4   0x0400, Wishbone ERR in STAT, not STICKYERR
    # Uart.scala             P5   0x0500, RX is a pop port
  hw/test/swdcap/                 scalatest: config and register contract (P0); SwdRemoteBitbang
                                  (remote_bitbang server for OpenOCD); SpinalSim: decoder,
                                  ID window, EIO, reserved-window STICKYERR (P1, P2)
  sim/                            P1a lane with a real OpenOCD: run_openocd.sh, openocd_sim.cfg
                                  (remote_bitbang), p1_check.tcl
  gen/SwdcapTop.v                 generated; what non-Spinal users instantiate. Ports: clk, reset,
                                  swclk, swdio_i / swdio_o / swdio_oe (pad is the design's), plus
                                  instrument ports. Header records the SpinalHDL commit and the
                                  generator options
  gen/silicon/SwdcapTop.v    PT   the same module from SwdcapConfig.tinyTapeout (10-bit DMI
                                  address, async SWCLK-domain reset); what the area check hardened
  boards/arty/swdcap_arty.py      minimal LiteX SoC (stock Arty platform and clocking, no CPU) +
                                  two SWD pads on JB; --debug-clk-div for a slow debug clock.
                                  Not in a directory called litex/, which would shadow the
                                  LiteX Python package
  # Tiny Tapeout is a separate repository, https://github.com/disdi/ttsky-swdcap: info.yaml,
  # src/tt_um_disdi_swdcap.v wrapper, two-clock SDC, cocotb RTL and gate-level test
  constr/arty_jb.xdc              the same pad and clock constraints for a non-LiteX design
                                  (derived from the verified LiteX build; not run by itself)
  openocd/swdcap.cfg              swd newdap, dap create, swdcap_rd / swdcap_wr / swdcap_probe /
                                  swdcap_addr_width
  openocd/p1_check.tcl            p1_check and p1_stress, used in simulation and on hardware
  openocd/p2_check.tcl            p2_check (EIO, optional loopback mode) and p2_walk
  openocd/pt_check.tcl       PT   pt_reset_arm and pt_reset_check: does a reset reach the SWCLK
                                  domain (async for the silicon shape, boot for the FPGA shape)
  py/
    pyproject.toml                package "swdcap", console entry point `swdcap`
    swdcap/cli.py                 probe, eio-read / eio-write
    swdcap/openocd.py             Tcl RPC client (port 6666)
  docs/regmap.md                  the frozen v0.1 contract: AP registers, DMI map, ID and EIO windows
  docs/integration.md             how a design instantiates, pads, constrains and clocks SwdcapTop
  docs/rp2040-pmod-probe.md       RP2040 Pmod as the CMSIS-DAP probe, plugged straight into JB;
                                  the firmware is disdi/debugprobe, branch rp2040-pmod
```

Ground and VTREF are wiring, not constraints: GND on JB11, a second GND from the breakout to JB5,
and VTREF on JB12 (MCU-Link only; leave it open on the Pi Debug Probe). Never put SWCLK and SWDIO
on adjacent pins.

## Risks

| Risk | Mitigation |
|---|---|
| Rig faults masquerading as RTL bugs (VTREF / SWCLK / SWDIO leads) | known-good reference bitstream before every bring-up; a raw SWCLK/SWDIO line check when it fails; reproduce any failure on an independent rebuild |
| SWDIO→SWCLK crosstalk | Second ground JP2.3→JB5; separated leads; JB3/JB7, never adjacent pins |
| Gateway CDC at untested clock ratios | P1 exit runs debug clock both below and above SWCLK |
| TT mux delay (~20 ns round trip) limits SWCLK | Start at 1 MHz on silicon; 20 ns is small against 125 ns at 4 MHz, so measure the ceiling |
| Core does not fit 1x2 SKY tiles | Checked 2026-10-05: 69.0 % utilisation with 515 flops, ELA / WB / UART generated out. It fits only with a 0.05 ns hold margin, so the headroom is small. Re-run the area check after any RTL change; trims: fewer hold buffers, narrower `scratchWidth`, then narrower EIO widths |
| Silicon powers up with undefined SWD state | `swdAsyncReset = true`: SWCLK domain reset from `rst_n`. Checked on the Arty with the reset button and in the gate-level simulation, where every flop starts undefined (2026-10-05) |
| SWCLK on a data pin has no clock constraints or tree | Two-clock SDC through `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE`; the flow built the second clock tree in the area check |
| SWDIO floats on TT (no internal pull-up) | 10 kΩ–100 kΩ from `uio[4]` to 3.3 V, on a TPH2 test point, not in series; rehearsed on the Arty in PT |
| SWCLK floats when the probe is idle (no pull on the Arty, on the TT pad or on the demo board) | Open. A floating clock pin can clock the DP; a pull resistor on SWCLK at the target is the candidate fix |
| `rst_n` released at an arbitrary moment relative to `clk` | Two-flop reset synchroniser in the Tiny Tapeout wrapper: asynchronous assert, release aligned to `clk` |
| The RP2350 on the TT demo board drives `uio[2]` (GPIO27) / `uio[4]` (GPIO29) | Keep `uio_oe_pico` bits 2 and 4 clear while an external probe is attached |
| Demo-board `clk` stopped or `rst_n` never pulsed | Bring-up order in the pinout section: select, start `clk`, pulse `rst_n`, then probe |
| TT bidirectional header does not follow the assumed Pmod layout | Checked 2026-10-05 on the v3 demo board (rev 3.3): pin 3 is `uio[2]`, pin 7 is `uio[4]`. Check again if an older board revision is used |
| Tools mistake the gateway for a CPU | DM range reads 0 → `dmstatus.version = 0`; documented in the README |
| `dap info` output misleads users | Documented; `swdcap probe` is the supported identification path |
| Later bus bridge wedges the DAP | When generated, Wishbone ERR goes in STAT, not STICKYERR |
| DPIDR designer code is a squat (Facebook Inc) | Documented upstream and accepted in [blackmagic#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322); identity is DPIDR + AP_IDR together; any change goes upstream in lockstep |

## Exit for a public v0.1

- Arty bitstream, JB harness documented, `openocd/swdcap.cfg` in tree, generated `SwdcapTop.v`
  (EIO on, ELA / WB / UART off) plus the LiteX wrapper.
- `swdcap probe` prints `AP_IDR 0x74726976`, magic `0x43445753`, and FEATURES bit 0 only.
- EIO toggles an LED and reads the inputs back.
- An access to `0x0300` sets STICKYERR, and the next access after ABORT works.
- LibreLane fits the TT wrapper in 1x2 SKY tiles.
- TT gate-level simulation passes with X-initialised flops (reset, line reset, MAGIC, EIO,
  STICKYERR recovery).
- README states:
  - SWD slave only, CMSIS-DAP master, stock OpenOCD `dap apreg`.
  - The transport is the SpinalHDL SWD DMI gateway: upstream components and AP map unchanged.
  - ELA, bus peek and UART are not in this bitstream.
  - Not RSDP, and not a CPU debugger unless P7.
