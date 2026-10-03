package swdcap

import spinal.core._
import spinal.lib._

/** ID window at 0x0100: who this is, what was generated, and a scratch register. See docs/regmap.md. */
case class IdWindow(c: SwdcapConfig) extends Component {
  import SwdcapRegs._

  val io = new Bundle {
    val bus = slave(RegWindowBus())
  }

  val scratch = Reg(Bits(c.scratchWidth bits)) init(0)

  io.bus.rdata := 0
  io.bus.error := False
  switch(io.bus.offset) {
    is(ID_MAGIC - ID_BASE)        { io.bus.rdata := B(MAGIC, 32 bits) }
    is(ID_VERSION - ID_BASE)      { io.bus.rdata := B(VERSION, 32 bits) }
    is(ID_FEATURES - ID_BASE)     { io.bus.rdata := B(c.features, 32 bits) }
    is(ID_DEBUG_CLK_HZ - ID_BASE) { io.bus.rdata := B(BigInt(c.debugClkHz), 32 bits) }
    is(ID_EIO_WIDTH - ID_BASE)    { io.bus.rdata := B(c.eioWidthReg, 32 bits) }
    is(ID_ELA_WIDTH - ID_BASE)    { io.bus.rdata := 0 }
    is(ID_ELA_DEPTH - ID_BASE)    { io.bus.rdata := 0 }
    is(ID_SCRATCH - ID_BASE) {
      io.bus.rdata := scratch.resized
      when(io.bus.sel && io.bus.write) {
        scratch := io.bus.wdata.resized
      }
    }
    default { io.bus.error := True }
  }
}
