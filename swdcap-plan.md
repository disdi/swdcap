# swdcap — SWD fcapz plan

SWD analogue of fpgacapZero (<https://github.com/lcapossio/fpgacapZero>). The FPGA (or soft IP)
is the **target**, not the probe. A stock CMSIS-DAP probe and stock OpenOCD reach on-chip
instruments over two wires, with no JTAG TAP and no vendor BSCAN.

The transport is the **existing SWD DMI gateway, unchanged**: the same SW-DP and designer-AP
that carry the RISC-V DMI on VexRiscv / VexiiRiscv / ElemRV. swdcap puts instruments on its
DMI bus instead of, or next to, a Debug Module.

```
PC — stock OpenOCD (`dap apreg`) + Python CLI over Tcl RPC
  │
CMSIS-DAP probe (SWD master: Pi Debug Probe, MCU-Link, any DAPLink)
  │  SWCLK + SWDIO + GND (+ VTREF from target 3V3)
  │
DebugTransportModuleSwd ....... SpinalHDL dev, unchanged
  │   SwdPhy + SwdDp            (spinal.lib.com.swd, #1966)              [SWCLK domain, BOOT reset]
  │   SwdDmiGateway             AP_IDR / DMI_ADDR / DMI_DATA / POSTED_READ
  │   ccToggle CDC              one outstanding access, WAIT until done
  │
DebugBus(addressWidth = 16) ── DMI decoder                                [debug clock]
  ├── 0x0000–0x007F  reserved for a RISC-V DM (P7); reads 0 when absent
  ├── ID · EIO · ELA · bus bridge · UART      (DebugBusSlaveFactory register files)
  └── ELA sample RAM window
```

## Non-goals (v0.1)

- Full fcapz-sized ILA
- Multi-drop SWD (DPv2 TARGETSEL)
- MEM-AP, ROM table, ADIv6. The gateway is a designer-AP, so stock `mdw` and `dap info` do not apply.
- Any change to the gateway RTL or its AP register map
- Secure debug / authentication
- Black Magic Probe as an instrument host. The BMP patch matches the gateway AP_IDR but expects a DM.

## Reuse, not rewrite

Everything from the pins to the DMI bus already exists. It is merged upstream and
hardware-verified on the Arty (Pi Debug Probe, MCU-Link, BMP) and the Kopflos:

| Piece | Source | What it already gives swdcap |
|---|---|---|
| `SwdPhy`, `SwdDp` | `spinal.lib.com.swd` (SpinalHDL#1966) | Line reset, turnaround, parity, ACK; DPIDR, CTRL/STAT, SELECT, RDBUFF/RESEND, ABORT, sticky errors, WAIT gating, posted reads |
| `SwdDmiGateway` | `spinal.lib.cpu.riscv.debug.DebugTransportModuleSwd` | Designer-AP, the CDC (`ccToggle`, BOOT-reset SWCLK domain), one outstanding DMI access, `DebugRsp.error` → STICKYERR |
| `DebugBus`, `DebugBusSlaveFactory` | `spinal.lib.cpu.riscv.debug.DebugInterfaces` | 32-bit word-addressed bus plus a register-file factory for the instruments |
| Raw-AP host procs | `litex/litex/tools/debug/vexriscv_swd.cfg` | `dmi_read` / `dmi_write` over `dap apreg`, already proven on stock OpenOCD master |

**New work is only below `DebugBus`:** the decoder and the instruments. The deliverable is
generated Verilog (`SwdcapTop`), so users do not need SpinalHDL, plus a LiteX wrapper for Arty
bring-up, modelled on `arty_vexii_swd.py`.

`SwdcapTop` = `DebugTransportModuleSwd(p.addressWidth = 16)` + decoder + instruments.
`addressWidth` is an existing parameter, not an RTL change. The 16-bit DMI word address gives a
256 KiB map. That is within the Debug Spec §3.1.1 range of 7–32 bits, so a DM can share the bus
later.

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
  DMI_ADDR stays put. Every bulk path uses pop ports (ELA, UART RX).
- **CDC is already solved.** `SwdDp` answers WAIT while the crossed access is pending, and the
  host's retry supplies the SWCLK edges. Instruments sit in the `DebugBus` (debug clock) domain.
  Only instruments that sample on another clock (the ELA) need their own internal crossing.
- **Errors.** A `DebugRsp.error` from the decoder → STICKYERR, which OpenOCD clears via ABORT.
  An unmapped address returns an error, except the reserved DM range (below).
- **Tool identification.** OpenOCD's `vexriscv-gateway` backend and the BMP patch recognise
  `0x74726976` and look for a DM at DMI `0x00–0x7F`; the backend fixes `abits` at 7. With no DM,
  that range reads 0, and `dmstatus.version = 0` means "no Debug Module present" (Debug Spec
  §3.1.14.1), so those tools stop cleanly instead of misreading instruments.

## DMI memory map (word addresses, `addressWidth = 16`)

| DMI word | Byte equiv. | Window | Notes |
|---|---|---|---|
| `0x0000–0x007F` | `0x0_0000` | DM reserved | Reads 0, writes ignored, no error. A DM goes here in P7 |
| `0x0100` | `0x0_0400` | ID | Magic, version, features, clock, widths, scratch |
| `0x0200` | `0x0_0800` | EIO | IN, OUT, OE, WIDTH |
| `0x0300` | `0x0_0C00` | ELA ctrl | ARM, TRIG_VALUE, TRIG_MASK, STATUS, SAMPLE_COUNT, RD_PTR, RD_POP |
| `0x0400` | `0x0_1000` | Bus bridge | ADDR, WDATA, RDATA, CMD, STAT. One outstanding (P4) |
| `0x0500` | `0x0_1400` | UART | TX, RX_POP, STATUS, BAUD_DIV |
| `0x8000–0xFFFF` | `0x2_0000` | ELA sample RAM | Random access, up to 32 Ki words. Bulk readout uses `RD_POP` |

### ID window (draft, frozen at end of P0)

| Word | Register | Value |
|---|---|---|
| `0x0100` | MAGIC | `0x4344_5753` (`"SWDC"`, little-endian bytes) |
| `0x0101` | VERSION | `major[31:16] minor[15:8] patch[7:0]` |
| `0x0102` | FEATURES | bit 0 EIO, 1 ELA, 2 UART, 3 BUS_WB, 4 BUS_AXI, 5 DM present |
| `0x0103` | DEBUG_CLK_HZ | Instrument (DebugBus) clock |
| `0x0104` | EIO_WIDTH | Bits of IN / OUT |
| `0x0105` | ELA_WIDTH | Probe width (bits) |
| `0x0106` | ELA_DEPTH | Samples |
| `0x0107` | SCRATCH | R/W, reset `0` |

The host reads FEATURES and the widths, and never hard-codes them. It can also read the
DMI_ADDR width by writing `0xFFFFFFFF` to AP `0x04` and reading it back.

## Pinout

The Arty bring-up reuses the existing **JB SWD harness**, so `swd_rawbits.sh` and the golden
gate apply unchanged:

| Signal | Arty | Notes |
|---|---|---|
| SWCLK | JB3 (D15) | MRCC, so the clock reaches the global network |
| SWDIO | JB7 (J17) | Pull-up in the XDC; **not** JB4 (C15 is D15's differential partner, crosstalk) |
| GND | JB11 | |
| GND (second) | JB5 ← breakout JP2.3 | Required. Without it the DP is double-clocked |
| VTREF | JB12 (3V3) | **Target supplies it, the probe senses it.** MCU-Link needs it wired. The Pi Debug Probe has no VTREF pin; leave it open |
| nRESET (opt.) | TBD in P0 | Open-drain. Not adjacent to JB3/JB7 |

Direct wires only; a PmodTPH2 pass-through kills the link.

**Kopflos port (after v0.1):** ElemRV harness on PMOD1 (SWCLK J3, SWDIO K2). PMOD2 M5/T4 is the
Steg console.

## Phases

### P0 — contract

- Freeze the ID window, FEATURES and the DMI map above.
- **DPIDR / AP_IDR:** inherited unchanged from the gateway, `0x0BA11AAB` / `0x74726976`. Decided;
  see **Decided** below.
- Bus bridge target: **Wishbone** (decided).
- Pick the nRESET pin.

### P1 — gateway + ID window

**P1a sim.** `SwdcapTop` with the ID window only, under Verilator. LiteX `swdremote` + stock
OpenOCD master (`~/openocd-master` or a `master` worktree) — the existing raw-AP smoke lane,
pointed at the ID window instead of `dmstatus`.

**P1b Arty.** Before loading the new image, run `./golden/verify.sh` to prove the rig. Then, with
the Pi Debug Probe:

```
source [find interface/cmsis-dap.cfg]
transport select swd
adapter speed 1000
swd newdap swdcap cpu -expected-id 0x0ba11aab
dap create swdcap.dap -chain-position swdcap.cpu
init

proc swdcap_rd {a}   { swdcap.dap apreg 0 0x04 $a; return [swdcap.dap apreg 0 0x08] }
proc swdcap_wr {a v} { swdcap.dap apreg 0 0x04 $a; swdcap.dap apreg 0 0x08 $v }

echo [format "AP_IDR   0x%08x" [swdcap.dap apreg 0 0x00]]   ;# expect 0x74726976
echo [format "MAGIC    0x%08x" [swdcap_rd 0x0100]]           ;# expect 0x43445753
echo [format "dmstatus 0x%08x" [swdcap_rd 0x0011]]           ;# expect 0 (no DM)
swdcap_wr 0x0107 0xa5a5a5a5
echo [format "SCRATCH  0x%08x" [swdcap_rd 0x0107]]
swdcap_rd 0x4000                                             ;# unmapped: expect STICKYERR
```

**Exit:**
- DPIDR, AP_IDR and MAGIC stable.
- Scratch read/write stable at 1 MHz, then 4 MHz.
- An unmapped access sets STICKYERR, and the next access after ABORT succeeds.
- Repeat with a debug clock below **and** above SWCLK. The gateway CDC is proven for the DM's
  clock ratios, not for arbitrary ones.

### P2 — EIO

Same job as fcapz `eio-read` / `eio-write`. Wire LEDs and buttons. The host is still the
`swdcap_rd` / `swdcap_wr` procs.

### P3 — ELA, small

- 32-bit probes, depth 256 or 1024. The sample clock may differ from the debug clock, so the
  crossing is internal to the ELA.
- Trigger: value + mask, one comparator.
- Status: idle / armed / triggered / done.
- Readout: write `RD_PTR`, set DMI_ADDR to `RD_POP` once, then read DMI_DATA N times. One AP
  read per sample instead of two.

### P4 — bus bridge

- Indirect Wishbone master, one outstanding transaction. Write ADDR (and WDATA), write CMD =
  read/write, poll STAT, read RDATA. Wishbone ERR → STAT error bit, not STICKYERR, so a bad
  target address does not wedge the DAP.
- AXI4-Lite is a later variant (FEATURES bit 4).

### P5 — UART

- TX/RX FIFO, status bits, BAUD_DIV. RX is a pop port.
- Replaces EJTAG-UART for designs with no spare UART pin.

### P6 — host

- **P6a**: `tcl/target/swdcap.cfg` in tree: the P1b DAP setup plus `swdcap_rd` / `swdcap_wr` /
  `swdcap_pop <addr> <n>` procs. Stock OpenOCD master; no `riscv` or `mem_ap` target.
- **P6b**: `swdcap` Python CLI over the OpenOCD Tcl RPC port (6666), so it works with any adapter
  OpenOCD supports. Verbs follow fcapz names where they exist:
  - `probe` (AP_IDR / magic / version / features / widths / DMI_ADDR width)
  - `eio-read` / `eio-write`
  - `ela-arm` / `ela-status` / `ela-dump --vcd`
  - `bus-read` / `bus-write`
  - `uart` (console)
- Throughput: each Tcl `apreg` is one USB round trip. If `ela-dump` of 1024 samples is too slow,
  batch the pops in a single Tcl proc so OpenOCD queues them. Measure before optimising.

### P7 — RISC-V DM on the same bus (after v0.1, optional)

- Put a VexRiscv/VexiiRiscv `DebugModule` at DMI `0x00–0x7F` behind the same decoder; set
  FEATURES bit 5.
- The existing `vexriscv-gateway` OpenOCD `riscv` target (abits 7) and the BMP patch then debug
  the CPU **unchanged**, while the instruments stay reachable through `dap apreg` above `0x7F`.
- Check how OpenOCD's DM scan (`nextdm`) and BMP behave with a DMI_ADDR wider than 7 bits before
  claiming this.
- Any conformance statement must read "RISC-V Debug Specification, **with custom DTM**".

## Host contract

Any CMSIS-DAP probe is the SWD master. OpenOCD is stock master, using raw AP access only:

```
source [find interface/cmsis-dap.cfg]
transport select swd
adapter speed 2000
source [find target/swdcap.cfg]      ;# swd newdap / dap create / swdcap_rd / swdcap_wr / swdcap_pop
```

## Risks

| Risk | Mitigation |
|---|---|
| Rig faults masquerading as RTL bugs (VTREF / SWCLK / SWDIO leads) | `./golden/verify.sh` before every bring-up; `swd_rawbits.sh` on a red result; reproduce any failure on an independent rebuild |
| SWDIO→SWCLK crosstalk | Second ground JP2.3→JB5; separated leads; JB3/JB7, never adjacent pins |
| Gateway CDC at untested clock ratios | P1 exit runs debug clock both below and above SWCLK |
| Readout throughput (no autoincrement) | Pop ports; batched Tcl procs; measured in P3 |
| Tools mistake the gateway for a CPU | DM range reads 0 → `dmstatus.version = 0`; documented in the README |
| `dap info` output misleads users | Documented; `swdcap probe` is the supported identification path |
| Bus bridge error wedges the DAP | Wishbone ERR reported in STAT, not as STICKYERR |
| DPIDR designer code is a squat (Facebook Inc) | Documented upstream and accepted in blackmagic#2322; identity is DPIDR + AP_IDR together; any change goes upstream in lockstep |

## Exit for a public v0.1

- Arty bitstream, JB harness documented, `swdcap.cfg` in tree, generated `SwdcapTop.v` + LiteX
  wrapper.
- `swdcap probe` prints AP_IDR, magic, version, features.
- EIO toggles an LED.
- ELA writes a VCD of a counter.
- A bus read returns a word that a free-running master wrote.
- UART echo through `swdcap uart`.
- README states:
  - SWD slave only, CMSIS-DAP master, stock OpenOCD `dap apreg`.
  - The transport is the unchanged SpinalHDL SWD DMI gateway.
  - Not RSDP, and not a CPU debugger unless P7.
