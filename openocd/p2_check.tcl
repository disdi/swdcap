# P2 check: EIO. Run after "init"; source p1_check.tcl first (it provides p1_fail).
#
#   p2_check            identify, FEATURES bit 0, EIO_OUT write / read-back
#   p2_check loopback   also expects EIO_IN to follow EIO_OUT (simulation, or a loopback build)

proc p2_check {{mode ""}} {
	swdcap_probe

	set features [swdcap_rd 0x0102]
	if {($features & 1) == 0} { p1_fail "FEATURES bit 0 (EIO) is clear" }
	set width [swdcap_rd 0x0104]
	set out_bits [expr {($width >> 8) & 0xff}]
	set in_bits  [expr {$width & 0xff}]
	if {$out_bits < 1 || $in_bits < 1} { p1_fail "EIO_WIDTH reports no pins" }
	set out_mask [expr {(1 << $out_bits) - 1}]
	set in_mask  [expr {(1 << $in_bits) - 1}]
	set both     [expr {$out_mask & $in_mask}]

	foreach v {0x00000001 0x000000aa 0x00000055 0xffffffff 0x00000000} {
		swdcap_eio_write $v
		set got [swdcap_rd 0x0201]
		if {$got != ($v & $out_mask)} { p1_fail [format "EIO_OUT wrote 0x%08x, read 0x%08x" $v $got] }
		if {$mode eq "loopback"} {
			set in [swdcap_eio_read]
			if {($in & $both) != ($v & $both)} { p1_fail [format "EIO_IN 0x%08x does not follow EIO_OUT 0x%08x" $in $v] }
		}
	}
	echo "EIO_OUT      write / read-back ok ($out_bits bits)"
	if {$mode eq "loopback"} { echo "EIO_IN       follows EIO_OUT ($in_bits bits)" }

	# A write to EIO_IN is ignored, not an error. 0x0202 is not implemented and must error.
	swdcap_wr 0x0200 0xffffffff
	if {![catch {swdcap_rd 0x0202} msg]} { p1_fail "read of 0x0202 must return an error" }
	if {[swdcap_rd 0x0100] != 0x43445753} { p1_fail "no recovery after the 0x0202 error" }
	echo "0x0202       error, recovered"

	echo [format "EIO_IN       0x%08x" [swdcap_eio_read]]
	echo "PASS: P2 check"
}

# Walk one lit output across the EIO outputs, for a look at the LEDs.
proc p2_walk {{rounds 2} {delay_ms 150}} {
	set out_bits [expr {([swdcap_rd 0x0104] >> 8) & 0xff}]
	for {set r 0} {$r < $rounds} {incr r} {
		for {set i 0} {$i < $out_bits} {incr i} {
			swdcap_eio_write [expr {1 << $i}]
			sleep $delay_ms
		}
	}
	swdcap_eio_write 0
}
