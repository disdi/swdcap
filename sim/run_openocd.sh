#!/usr/bin/env bash
# Runs the P1 check with a real OpenOCD against the simulated design.
#
#   sim/run_openocd.sh [fpga|silicon]
#
# OPENOCD selects the OpenOCD binary (default: openocd on PATH). Any stock OpenOCD with the
# remote_bitbang driver and SWD support works.
set -euo pipefail
cd "$(dirname "$0")/.."

shape="${1:-fpga}"
openocd="${OPENOCD:-openocd}"
port=44854
log="simWorkspace/openocd_${shape}.log"
mkdir -p simWorkspace

sbt -batch "Test/runMain swdcap.SwdcapOpenocdSim ${shape} ${port}" > "simWorkspace/sim_${shape}.log" 2>&1 &
sim_pid=$!
trap 'kill ${sim_pid} 2>/dev/null || true' EXIT

for _ in $(seq 1 600); do
	grep -q "listening on localhost:${port}" "simWorkspace/sim_${shape}.log" 2>/dev/null && break
	kill -0 ${sim_pid} 2>/dev/null || { echo "simulation exited early; see simWorkspace/sim_${shape}.log"; exit 1; }
	sleep 0.5
done
grep -q "listening on localhost:${port}" "simWorkspace/sim_${shape}.log" || { echo "simulation did not start"; exit 1; }

set +e
"${openocd}" -f sim/openocd_sim.cfg -f openocd/swdcap.cfg -f sim/p1_check.tcl \
	-c "init" -c "p1_check" -c "shutdown" 2>&1 | tee "${log}"
set -e

grep -q "^PASS: P1 check" "${log}" && ! grep -q "^FAIL" "${log}"
