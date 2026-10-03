package swdcap

import spinal.core._
import spinal.lib._
import spinal.lib.com.swd._
import spinal.lib.cpu.riscv.debug._

/**
 * swdcap: SWD pins -> SwdPhy -> SwdDp -> DMI gateway -> DMI decoder -> instrument windows.
 *
 * The SWD side is the upstream SpinalHDL transport, unchanged. This component assembles the same
 * pieces as DebugTransportModuleSwd (SwdPhyDp + SwdDmiGateway) rather than instantiating it, for
 * one reason: the SWCLK-domain reset. Upstream fixes it to BOOT (FPGA bitstream initialisation).
 * With swdAsyncReset it is reset asynchronously from the debug reset instead, which silicon needs.
 *
 * Ports: clk / reset are the debug clock and reset (decoder, instruments, far side of the CDC).
 * swclk clocks the SWD side. swdio is exposed as i / o / oe; the pad belongs to the design.
 */
case class SwdcapTop(c: SwdcapConfig) extends Component {
  import SwdcapRegs._

  require(!c.withEio, "EIO is implemented in P2; generate with withEio = false until then")

  val io = new Bundle {
    val swclk    = in  Bool()
    val swdio_i  = in  Bool()
    val swdio_o  = out Bool()
    val swdio_oe = out Bool()
  }
  noIoPrefix()

  val debugCd = ClockDomain.current

  val swdCd = if (c.swdAsyncReset) {
    ClockDomain(
      clock  = io.swclk,
      reset  = debugCd.readResetWire,
      config = ClockDomainConfig(resetKind = ASYNC, resetActiveLevel = debugCd.config.resetActiveLevel)
    )
  } else {
    ClockDomain(clock = io.swclk, config = ClockDomainConfig(resetKind = BOOT))
  }

  // ---- SWD transport: the upstream pieces, wired as in DebugTransportModuleSwd ----
  val core = swdCd on SwdPhyDp(DPIDR)
  core.io.swdio.read := io.swdio_i
  io.swdio_o  := core.io.swdio.write
  io.swdio_oe := core.io.swdio.writeEnable

  val gateway = new SwdDmiGateway(
    p       = DebugTransportModuleParameter(addressWidth = c.addressWidth, version = 1, idle = 7),
    swdCd   = swdCd,
    debugCd = debugCd,
    apIdr   = AP_IDR
  )
  gateway.swdLogic.apCmd << core.io.ap.cmd
  core.io.ap.rsp << gateway.swdLogic.apRsp

  // ---- DMI decoder (debug clock) ----
  // Whether a window answers is decided by what was generated, never by the address width: a
  // window that fits in addressWidth bits but was not generated returns an error.
  val decoder = new Area {
    val bus = gateway.systemLogic.bus
    bus.cmd.ready := True

    val address = bus.cmd.address
    val window  = address(c.addressWidth - 1 downto 8)
    val offset  = address(7 downto 0)

    val rsp = Flow(DebugRsp())
    rsp.valid := bus.cmd.fire
    rsp.error := True          // unmapped unless a window below claims the access
    rsp.data  := 0

    // 0x0000-0x007F: reserved for a RISC-V Debug Module. Reads 0, writes ignored, no error.
    when(window === 0 && offset <= DM_LAST) {
      rsp.error := False
    }

    val id = IdWindow(c)
    id.io.bus.sel    := bus.cmd.fire && window === (ID_BASE >> 8)
    id.io.bus.write  := bus.cmd.write
    id.io.bus.offset := offset
    id.io.bus.wdata  := bus.cmd.data
    when(window === (ID_BASE >> 8)) {
      rsp.error := id.io.bus.error
      rsp.data  := id.io.bus.rdata
    }

    bus.rsp << rsp.stage()
  }
}

/** Generates gen/SwdcapTop.v, the netlist a non-SpinalHDL design instantiates. */
object SwdcapTopVerilog extends App {
  SpinalConfig(targetDirectory = "gen").generateVerilog(SwdcapTop(SwdcapConfig(withEio = false)))
}
