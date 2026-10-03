# swdcap register map

**Frozen for v0.1** (2026-10-03, VERSION `0.1.0`). A change to anything on this page bumps
VERSION. The machine-readable form is [`SwdcapRegs.scala`](../hw/spinal/swdcap/SwdcapRegs.scala);
keep the two in step.

There are two layers: the four access-port (AP) registers of the SWD DMI gateway, which the host
reaches with OpenOCD `dap apreg`, and the DMI word address space behind them, where the
instruments live.

## Transport identity

| Register | Value | Note |
|---|---|---|
| DPIDR | `0x0BA11AAB` | DPv1, part `0xBA`, designer `[11:1] = 0x555` |
| AP_IDR | `0x74726976` | ASCII `triv`; marks the SpinalHDL SWD DMI gateway, not a MEM-AP |

Both are inherited unchanged from the SpinalHDL gateway. The designer code is a documented squat
(JEP106 continuation 10, identity `0x55`), accepted in
[blackmagic#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322). Tools identify the
transport by DPIDR and AP_IDR together.

## AP registers (gateway, unchanged)

| Offset | Register | Access | Behaviour |
|---|---|---|---|
| `0x00` | AP_IDR | RO | `0x74726976` |
| `0x04` | DMI_ADDR | RW | DMI **word** address, `addressWidth` bits. Bits above that are not stored and read 0. Persists across accesses |
| `0x08` | DMI_DATA | RW | A read or a write performs one DMI access at DMI_ADDR. No autoincrement |
| `0x0C` | POSTED_READ | RO | Result of the last successful DMI read |

- Only A[3:2] is decoded. APSEL and APBANKSEL are ignored, so `dap info` (which reads `0xFC`)
  lands on POSTED_READ and is not meaningful.
- A DMI access in flight makes the DP answer WAIT; the host retries.
- A DMI error sets STICKYERR in the DP. Clear it with ABORT (OpenOCD does this).

`addressWidth` is 16 on the FPGA build and 10 on the Tiny Tapeout wrapper. The host finds it by
writing `0xFFFFFFFF` to DMI_ADDR and reading it back, and must not use addresses beyond it: with
10 bits, `0x0400` and above alias into `0x0000–0x03FF` instead of returning an error.

## DMI address space

Addresses are DMI word addresses. Every register is 32 bits.

| DMI words | Window | v0.1 | Behaviour |
|---|---|---|---|
| `0x0000–0x007F` | Debug Module | reserved | Reads 0, writes ignored, **no error**. `dmstatus` (`0x11`) reads 0, which means "no Debug Module present" |
| `0x0080–0x00FF` | — | unmapped | Error |
| `0x0100–0x0107` | ID | present | See below |
| `0x0108–0x01FF` | — | unmapped | Error |
| `0x0200–0x0201` | EIO | present when FEATURES bit 0 is set | See below |
| `0x0202–0x02FF` | — | unmapped | Error. `0x0202` is held for a later EIO output-enable register |
| `0x0300–0x03FF` | ELA control | reserved | Error until generated |
| `0x0400–0x04FF` | Wishbone bridge | reserved | Error until generated |
| `0x0500–0x05FF` | UART | reserved | Error until generated |
| `0x0600–0x7FFF` | — | unmapped | Error |
| `0x8000–0xFFFF` | ELA sample RAM | reserved | Error until generated |

Access rules:

- **Error** means the DMI access completes with an error, so the DP sets STICKYERR. Read data is
  undefined. The next access works after ABORT clears the flag.
- A write to a read-only register is ignored and is **not** an error.
- If EIO is not generated, `0x0200–0x0201` are unmapped (error).

### ID window (`0x0100`)

| Word | Register | Access | Reset | Value |
|---|---|---|---|---|
| `0x0100` | MAGIC | RO | — | `0x43445753` (`"SWDC"`, little-endian bytes) |
| `0x0101` | VERSION | RO | — | `major[31:16]`, `minor[15:8]`, `patch[7:0]`. v0.1 is `0x00000100` |
| `0x0102` | FEATURES | RO | — | Instruments generated into this build; bits below |
| `0x0103` | DEBUG_CLK_HZ | RO | — | Debug (instrument) clock in Hz, fixed at generation. `0` = unknown (for example a clock set at run time) |
| `0x0104` | EIO_WIDTH | RO | — | `out[15:8]`, `in[7:0]`: number of EIO output and input bits. `0` when EIO is not generated |
| `0x0105` | ELA_WIDTH | RO | — | Probe width in bits. `0` in v0.1 |
| `0x0106` | ELA_DEPTH | RO | — | Capture depth in samples. `0` in v0.1 |
| `0x0107` | SCRATCH | RW | `0` | `scratchWidth` bits (32 by default); higher bits read 0 and ignore writes. No side effects |

FEATURES bits:

| Bit | Name | v0.1 |
|---|---|---|
| 0 | EIO | 1 |
| 1 | ELA | 0 |
| 2 | UART | 0 |
| 3 | BUS_WB (Wishbone bridge) | 0 |
| 4 | BUS_AXI (AXI4-Lite bridge) | 0 |
| 5 | DM (a Debug Module is present at `0x0000–0x007F`) | 0 |
| 31:6 | reserved | 0 |

### EIO window (`0x0200`)

| Word | Register | Access | Reset | Value |
|---|---|---|---|---|
| `0x0200` | EIO_IN | RO | — | The `eio_in` port, synchronised into the debug clock. Bits at and above the input width read 0 |
| `0x0201` | EIO_OUT | RW | `0` | Drives the `eio_out` port. Bits at and above the output width read 0 and ignore writes |

## Identifying a swdcap target

1. DPIDR reads `0x0BA11AAB`.
2. AP register `0x00` reads `0x74726976`.
3. DMI word `0x0100` reads `0x43445753`.
4. Read VERSION, FEATURES and the widths; never hard-code them.
5. Read back the DMI_ADDR width and refuse addresses beyond it.

## Generator options that change this map

| Option | Default | Tiny Tapeout | Effect on the map |
|---|---|---|---|
| `addressWidth` | 16 | 10 | Reachable DMI range; minimum 10 |
| `withEio` | true | true | FEATURES bit 0, the EIO window, EIO_WIDTH |
| `eioInWidth` / `eioOutWidth` | 8 / 8 | 8 / 8 | EIO_WIDTH; valid bits of EIO_IN and EIO_OUT |
| `scratchWidth` | 32 | 32 | Implemented bits of SCRATCH |
| `debugClkHz` | 0 | 0 | DEBUG_CLK_HZ |
| `swdAsyncReset` | false | true | None. It selects the reset of the SWCLK domain only |
| `withEla` / `withWb` / `withUart` | false | false | Not implemented in v0.1; setting one is rejected |
