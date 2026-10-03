# swdcap SWD pads on a Digilent Arty A7, Pmod JB, for a design that does not use LiteX.
#
# These are the constraints the LiteX wrapper (boards/arty/swdcap_arty.py) emits, with the port
# names changed to pmod_swclk / pmod_swdio. The LiteX build is verified on hardware; this file
# itself has not been run through Vivado. Rename the ports and the system clock to match your
# top level.
#
# Wiring, not constraints: GND on JB11, a second ground on JB5, VTREF on JB12 for probes that
# sense it.

# SWCLK: JB3, D15. Clock-capable pin, so the clock reaches the global network.
set_property LOC D15 [get_ports {pmod_swclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {pmod_swclk}]

# SWDIO: JB7, J17. Other row than D15's differential partner (C15 / JB4).
set_property LOC J17 [get_ports {pmod_swdio}]
set_property IOSTANDARD LVCMOS33 [get_ports {pmod_swdio}]
set_property PULLUP TRUE [get_ports {pmod_swdio}]

# SWCLK is driven by the probe, gated, and asynchronous to the rest of the design. 10 MHz is
# above the 4 MHz the link is run at.
create_clock -name pmod_swclk -period 100.0 [get_ports pmod_swclk]
set_clock_groups -asynchronous \
    -group [get_clocks -of [get_nets sys_clk]] \
    -group [get_clocks -of [get_ports pmod_swclk]]
