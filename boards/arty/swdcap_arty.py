#!/usr/bin/env python3
"""swdcap on a Digilent Arty A7: SwdcapTop on the 100 MHz system clock, SWD on Pmod JB.

A minimal LiteX SoC (no CPU): the stock litex-boards Arty platform and clocking, plus the two
SWD pads. Needs LiteX, litex-boards and Vivado.

    boards/arty/swdcap_arty.py --build --load
    boards/arty/swdcap_arty.py --debug-clk-div 256 --build --load   # debug clock below SWCLK

Wiring (Pmod JB), see docs/integration.md:

    SWCLK  JB3  (D15, clock-capable)       GND    JB11, and a second ground on JB5
    SWDIO  JB7  (J17, pull-up)             VTREF  JB12 (probes that sense it)
"""

import argparse
import os

from migen import *
from migen.fhdl.specials import Tristate
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.build.generic_platform import Subsignal, Pins, IOStandard, Misc
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from litex_boards.platforms import digilent_arty
from litex_boards.targets.digilent_arty import _CRG

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# JB is a high-speed Pmod (no series resistors). D15 is clock-capable; J17 is on the other row,
# away from D15's differential partner.
_swd_io = [
    ("swd", 0,
        Subsignal("swclk", Pins("pmodb:2")),                        # JB3 / D15
        Subsignal("swdio", Pins("pmodb:4"), Misc("PULLUP TRUE")),   # JB7 / J17
        IOStandard("LVCMOS33"),
    ),
]


class SwdcapArty(SoCMini):
    def __init__(self, variant="a7-35", sys_clk_freq=100e6, debug_clk_div=1, netlist=None):
        platform = digilent_arty.Platform(variant=variant, toolchain="vivado")
        self.crg = _CRG(platform, sys_clk_freq, with_dram=False)
        SoCMini.__init__(self, platform, sys_clk_freq, ident="swdcap on Arty A7")

        # Debug clock: the system clock, or a divided one to test a debug clock below SWCLK.
        self.cd_debug = ClockDomain()
        if debug_clk_div == 1:
            self.comb += self.cd_debug.clk.eq(ClockSignal("sys"))
        else:
            assert debug_clk_div >= 2 and debug_clk_div & (debug_clk_div - 1) == 0, \
                "--debug-clk-div must be a power of two"
            counter = Signal(max=debug_clk_div)
            self.sync += counter.eq(counter + 1)
            self.specials += Instance("BUFG", i_I=counter[-1], o_O=self.cd_debug.clk)
            platform.add_period_constraint(self.cd_debug.clk, 1e9*debug_clk_div/sys_clk_freq)
            platform.add_false_path_constraints(self.crg.cd_sys.clk, self.cd_debug.clk)
        self.specials += AsyncResetSynchronizer(self.cd_debug, ResetSignal("sys"))

        # SWD pads
        platform.add_extension(_swd_io)
        pads = platform.request("swd")
        swdio_i  = Signal()
        swdio_o  = Signal()
        swdio_oe = Signal()
        self.specials += Tristate(pads.swdio, swdio_o, swdio_oe, swdio_i)

        self.specials += Instance("SwdcapTop",
            i_clk      = self.cd_debug.clk,
            i_reset    = self.cd_debug.rst,
            i_swclk    = pads.swclk,
            i_swdio_i  = swdio_i,
            o_swdio_o  = swdio_o,
            o_swdio_oe = swdio_oe,
        )
        platform.add_source(netlist or os.path.join(REPO, "gen", "SwdcapTop.v"))

        # SWCLK is driven by the probe, gated, and asynchronous to everything else on the die.
        platform.add_period_constraint(pads.swclk, 1e9/10e6)
        platform.add_false_path_constraints(self.crg.cd_sys.clk, pads.swclk)
        if debug_clk_div != 1:
            platform.add_false_path_constraints(self.cd_debug.clk, pads.swclk)


def main():
    parser = argparse.ArgumentParser(description="swdcap on a Digilent Arty A7")
    parser.add_argument("--variant",       default="a7-35", help="a7-35 or a7-100")
    parser.add_argument("--debug-clk-div", default=1, type=int,
                        help="divide the 100 MHz system clock for the debug clock (power of two)")
    parser.add_argument("--netlist",       default=None, help="SwdcapTop netlist (default: gen/SwdcapTop.v)")
    parser.add_argument("--output-dir",    default=None, help="build directory")
    parser.add_argument("--build",         action="store_true", help="run Vivado")
    parser.add_argument("--load",          action="store_true", help="load the bitstream into the FPGA")
    args = parser.parse_args()

    soc = SwdcapArty(variant=args.variant, debug_clk_div=args.debug_clk_div, netlist=args.netlist)
    name = "swdcap_arty" if args.debug_clk_div == 1 else f"swdcap_arty_div{args.debug_clk_div}"
    output_dir = args.output_dir or os.path.join(REPO, "build", name)
    builder = Builder(soc, output_dir=output_dir, compile_software=False, csr_csv=None)
    builder.build(build_name=name, run=args.build)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))


if __name__ == "__main__":
    main()
