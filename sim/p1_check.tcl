# P1 check: identify the target, exercise SCRATCH, and confirm that a window that is not
# generated returns an error from which the link recovers. Run after "init".

proc p1_fail {msg} {
	echo "FAIL: $msg"
	shutdown error
}

proc p1_check {} {
	swdcap_probe

	foreach v {0xa5a5a5a5 0x5a5a5a5a 0x00000000} {
		swdcap_wr 0x0107 $v
		set got [swdcap_rd 0x0107]
		if {$got != $v} { p1_fail [format "SCRATCH wrote 0x%08x, read 0x%08x" $v $got] }
	}
	echo "SCRATCH      read/write ok"

	set dmstatus [swdcap_rd 0x0011]
	if {$dmstatus != 0} { p1_fail [format "dmstatus must read 0 (no Debug Module), got 0x%08x" $dmstatus] }
	echo "dmstatus     0 (no Debug Module)"

	# 0x0300 is the ELA window. It is not generated, so it must error even where it is addressable.
	if {![catch {swdcap_rd 0x0300} msg]} { p1_fail "read of 0x0300 must return an error" }
	echo "0x0300       error, as expected"

	set magic [swdcap_rd 0x0100]
	if {$magic != 0x43445753} { p1_fail [format "no recovery after the error: MAGIC 0x%08x" $magic] }
	echo "recovery     MAGIC reads again after the error"

	if {![catch {swdcap_wr 0x0300 1} msg]} { p1_fail "write of 0x0300 must return an error" }
	set magic [swdcap_rd 0x0100]
	if {$magic != 0x43445753} { p1_fail "no recovery after the write error" }
	echo "0x0300       write error, recovered"

	echo "PASS: P1 check"
}
