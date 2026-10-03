package swdcap

import spinal.core._
import spinal.lib._

/**
 * The register port between the DMI decoder and one 256-word window. Combinational: the window
 * answers in the cycle it is selected, and the decoder registers the response.
 *
 * error is the window's own verdict on the offset: true for a word the window does not implement.
 * A write to a read-only register is not an error; the window ignores it.
 */
case class RegWindowBus() extends Bundle with IMasterSlave {
  val sel    = Bool()
  val write  = Bool()
  val offset = UInt(8 bits)
  val wdata  = Bits(32 bits)
  val rdata  = Bits(32 bits)
  val error  = Bool()

  override def asMaster(): Unit = {
    out(sel, write, offset, wdata)
    in(rdata, error)
  }
}
