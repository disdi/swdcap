package swdcap

import spinal.core._
import spinal.lib._

/**
 * EIO window at 0x0200: sample input pins and drive output pins. See docs/regmap.md.
 *
 *   0x0200 EIO_IN   RO  eio_in, synchronised into the debug clock
 *   0x0201 EIO_OUT  RW  drives eio_out, reset 0
 */
case class Eio(c: SwdcapConfig) extends Component {
  import SwdcapRegs._

  val io = new Bundle {
    val bus     = slave(RegWindowBus())
    val eio_in  = in  Bits(c.eioInWidth bits)
    val eio_out = out Bits(c.eioOutWidth bits)
  }

  val inSync = BufferCC(io.eio_in)                       // asynchronous pins -> debug clock
  val outReg = Reg(Bits(c.eioOutWidth bits)) init(0)
  io.eio_out := outReg

  io.bus.rdata := 0
  io.bus.error := False
  switch(io.bus.offset) {
    is(EIO_IN - EIO_BASE) { io.bus.rdata := inSync.resized }
    is(EIO_OUT - EIO_BASE) {
      io.bus.rdata := outReg.resized
      when(io.bus.sel && io.bus.write) {
        outReg := io.bus.wdata.resized
      }
    }
    default { io.bus.error := True }
  }
}
