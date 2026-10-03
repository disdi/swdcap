package swdcap

import java.net.{InetAddress, ServerSocket}
import spinal.core._
import spinal.core.sim._

/**
 * OpenOCD `remote_bitbang` server for the SWD pins of a simulated design, so that a real OpenOCD
 * drives the simulation. It must run in the simulation thread. Protocol (SWD subset):
 *
 *   'd'..'g'   write {swclk, swdio} = bits 1 / 0 of (c - 'd')
 *   'O' / 'o'  host SWDIO drive enable / disable
 *   'c'        sample SWDIO, reply '0' or '1'
 *   'Q'        quit
 *
 * Other requests (LED, sleep, JTAG resets) are accepted and ignored. Simulated time advances
 * only as requests arrive; that is enough for a second, free-running clock to make progress,
 * because the host keeps clocking while it waits.
 */
object SwdRemoteBitbang {
  def serve(swclk: Bool, swdioI: Bool, swdioO: Bool, swdioOe: Bool, port: Int, timePerRequest: Int = 5): Unit = {
    val server = new ServerSocket(port, 1, InetAddress.getLoopbackAddress)
    println(s"[swdremote] listening on localhost:$port")
    val socket = try server.accept() finally server.close()
    socket.setTcpNoDelay(true)
    val in  = socket.getInputStream
    val out = socket.getOutputStream
    println("[swdremote] host connected")

    var hostOe    = false
    var hostSwdio = true
    def driveDut(): Unit = swdioI #= (if (hostOe) hostSwdio else true)   // released line: pull-up
    def sample(): Boolean =
      if (swdioOe.toBoolean) swdioO.toBoolean else if (hostOe) hostSwdio else true

    var running = true
    while (running) {
      val c = in.read()
      c match {
        case -1 | 'Q' => running = false
        case 'O' => hostOe = true;  driveDut(); sleep(timePerRequest)
        case 'o' => hostOe = false; driveDut(); sleep(timePerRequest)
        case 'c' =>
          sleep(1)
          out.write(if (sample()) '1' else '0'); out.flush()
        case x if x >= 'd' && x <= 'g' =>
          hostSwdio = ((x - 'd') & 1) != 0
          driveDut()
          sleep(1)                                   // data settles before the clock moves
          swclk #= (((x - 'd') >> 1) & 1) != 0
          sleep(timePerRequest)
        case _ =>                                    // 'B' 'b' 'Z' 'z' 'r'..'u' and the like
      }
    }
    socket.close()
    println("[swdremote] host disconnected")
  }
}

/**
 * Simulates SwdcapTop and waits for OpenOCD on a remote_bitbang port.
 *
 *   sbt "Test/runMain swdcap.SwdcapOpenocdSim [fpga|silicon] [port]"
 *
 * See sim/run_openocd.sh, which starts this and OpenOCD together.
 */
object SwdcapOpenocdSim extends App {
  val shape = args.headOption.getOrElse("fpga")
  val port  = args.lift(1).map(_.toInt).getOrElse(44854)
  val config = shape match {
    case "fpga"    => SwdcapConfig()
    case "silicon" => SwdcapConfig.tinyTapeout
    case other     => sys.error(s"unknown shape '$other', use fpga or silicon")
  }

  SimConfig.withConfig(SpinalConfig(targetDirectory = "simWorkspace/rtl"))
    .workspacePath("simWorkspace").workspaceName(s"openocd_$shape")
    .compile(SwdcapTop(config))
    .doSim { dut =>
      dut.io.swclk   #= false
      dut.io.swdio_i #= true
      dut.clockDomain.forkStimulus(period = 10)
      // EIO loopback: eio_in follows eio_out, so that a host can check both directions.
      dut.io.eio_in #= 0
      dut.clockDomain.onSamplings { dut.io.eio_in #= dut.io.eio_out.toBigInt }
      dut.clockDomain.waitSampling(10)
      SwdRemoteBitbang.serve(dut.io.swclk, dut.io.swdio_i, dut.io.swdio_o, dut.io.swdio_oe, port)
    }
}
