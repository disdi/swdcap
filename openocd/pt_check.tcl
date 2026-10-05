# PT rehearsal: does the reset button reach the SWCLK domain? Source p1_check.tcl first.
#
# The FPGA shape (BOOT reset) and the silicon shape (swdAsyncReset) both pass p1_check after a
# bitstream load, because an FPGA initialises every flop. The difference shows only when state is
# written, the reset is pulsed, and the state is read back before anything rewrites it:
#
#   run 1:   init; pt_reset_arm; shutdown          (LEDs light)
#            press and release the board reset
#   run 2:   init; pt_reset_check async; shutdown  silicon shape: DMI_ADDR must read 0
#            init; pt_reset_check boot;  shutdown  FPGA shape:    DMI_ADDR must still hold the value
#
# DMI_ADDR is a register in the SWCLK domain. SCRATCH and EIO_OUT are in the debug domain. In the
# silicon shape both must read 0 after the reset. In the FPGA shape the last DMI command can be
# replayed after the reset (see pt_reset_check), so only SCRATCH is required to be 0.

set PT_ADDR_PATTERN 0x0155

proc pt_reset_arm {} {
	global PT_ADDR_PATTERN SWDCAP_AP_REG_DMI_ADDR
	swdcap_probe
	swdcap_wr 0x0107 0xa5a5a5a5
	swdcap_eio_write 0xff
	# Last, and raw: swdcap_wr and swdcap_rd rewrite DMI_ADDR.
	swdcap.dap apreg 0 $SWDCAP_AP_REG_DMI_ADDR $PT_ADDR_PATTERN
	set got [swdcap.dap apreg 0 $SWDCAP_AP_REG_DMI_ADDR]
	if {$got != $PT_ADDR_PATTERN} { p1_fail [format "DMI_ADDR wrote 0x%04x, read 0x%04x" $PT_ADDR_PATTERN $got] }
	echo [format "armed        DMI_ADDR 0x%04x, SCRATCH 0xa5a5a5a5, EIO_OUT 0xff" $PT_ADDR_PATTERN]
	echo "now pulse the reset, then run pt_reset_check"
}

proc pt_reset_check {{shape async}} {
	global PT_ADDR_PATTERN SWDCAP_AP_REG_DMI_ADDR
	# First access after connecting: nothing may write DMI_ADDR before this read.
	set addr [swdcap.dap apreg 0 $SWDCAP_AP_REG_DMI_ADDR]
	echo [format "DMI_ADDR     0x%04x after the reset" $addr]
	if {$shape eq "async"} {
		if {$addr != 0} { p1_fail "the reset did not reach the SWCLK domain (DMI_ADDR kept its value)" }
	} elseif {$shape eq "boot"} {
		if {$addr != $PT_ADDR_PATTERN} { p1_fail "BOOT-reset shape: DMI_ADDR was expected to survive the reset" }
	} else {
		p1_fail "pt_reset_check: shape is async or boot"
	}
	set scratch [swdcap_rd 0x0107]
	set eio     [swdcap_rd 0x0201]
	if {$shape eq "boot"} {
		# Only the debug side of the command CDC is reset in this shape. If its toggle was at 1, the
		# debug side sees a new command when it leaves reset and runs the last DMI command again.
		# pt_reset_arm ends with the EIO_OUT write, so EIO_OUT 0xff here is that replay, not a
		# missed reset. SCRATCH is written earlier and must be 0.
		if {$scratch != 0} { p1_fail [format "SCRATCH 0x%08x, expected 0: was the reset pulsed?" $scratch] }
		if {$eio != 0} {
			echo [format "EIO_OUT      0x%08x: the last DMI command was replayed after the reset" $eio]
		} else {
			echo "EIO_OUT      0: no replay this time (command toggle was at 0)"
		}
	} else {
		if {$scratch != 0} { p1_fail [format "SCRATCH 0x%08x, expected 0: was the reset pulsed?" $scratch] }
		if {$eio != 0}     { p1_fail [format "EIO_OUT 0x%08x, expected 0: was the reset pulsed?" $eio] }
		echo "debug domain SCRATCH and EIO_OUT read 0"
	}
	echo "PASS: PT reset check ($shape)"
}
