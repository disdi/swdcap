package swdcap

import org.scalatest.funsuite.AnyFunSuite

class SwdcapConfigTest extends AnyFunSuite {
  import SwdcapRegs._

  test("MAGIC is SWDC as little-endian bytes") {
    val bytes = (0 until 4).map(i => ((MAGIC >> (8 * i)) & 0xFF).toInt.toChar).mkString
    assert(bytes == "SWDC")
  }

  test("VERSION is 0.1.0") {
    assert(VERSION == BigInt(0x00000100))
  }

  test("transport identity is the upstream gateway's") {
    assert(DPIDR == BigInt("0BA11AAB", 16))
    assert(((DPIDR >> 12) & 0xF) == 1, "SWD needs DPv1 or later")
    assert((DPIDR & 1) == 1, "DPIDR bit 0 reads as one")
    assert(AP_IDR == BigInt("74726976", 16))
  }

  test("default config is the FPGA build with only EIO") {
    val c = SwdcapConfig()
    assert(c == SwdcapConfig.fpga)
    assert(c.addressWidth == 16 && !c.swdAsyncReset)
    assert(c.features == BigInt(1))
    assert(c.eioWidthReg == BigInt(0x0808))
  }

  test("Tiny Tapeout config reaches ID and EIO but not the later windows") {
    val c = SwdcapConfig.tinyTapeout
    assert(c.addressWidth == 10 && c.swdAsyncReset)
    assert(c.features == BigInt(1))
    assert(c.reaches(ID_SCRATCH) && c.reaches(EIO_OUT) && c.reaches(ELA_BASE))
    assert(!c.reaches(WB_BASE) && !c.reaches(UART_BASE) && !c.reaches(ELA_RAM_BASE))
  }

  test("FPGA config reaches every window") {
    val c = SwdcapConfig.fpga
    assert(Seq(ID_BASE, EIO_BASE, ELA_BASE, WB_BASE, UART_BASE, ELA_RAM_BASE, 0xFFFF).forall(c.reaches))
    assert(!c.reaches(0x10000))
  }

  test("windows do not overlap the DM range or each other") {
    val bases = Seq(ID_BASE, EIO_BASE, ELA_BASE, WB_BASE, UART_BASE)
    assert(bases.forall(_ > DM_LAST))
    assert(bases == bases.sorted && bases.distinct.size == bases.size)
    assert(bases.forall(_ % 0x100 == 0) && ELA_RAM_BASE > bases.max)
  }

  test("EIO_WIDTH packs out[15:8] and in[7:0]") {
    assert(SwdcapConfig(eioInWidth = 4, eioOutWidth = 12).eioWidthReg == BigInt(0x0C04))
    assert(SwdcapConfig(withEio = false).eioWidthReg == BigInt(0))
    assert(SwdcapConfig(withEio = false).features == BigInt(0))
  }

  test("invalid options are rejected") {
    intercept[IllegalArgumentException](SwdcapConfig(addressWidth = 9))
    intercept[IllegalArgumentException](SwdcapConfig(addressWidth = 33))
    intercept[IllegalArgumentException](SwdcapConfig(eioInWidth = 0))
    intercept[IllegalArgumentException](SwdcapConfig(eioOutWidth = 33))
    intercept[IllegalArgumentException](SwdcapConfig(scratchWidth = 0))
    intercept[IllegalArgumentException](SwdcapConfig(withEla = true))
    intercept[IllegalArgumentException](SwdcapConfig(withWb = true))
    intercept[IllegalArgumentException](SwdcapConfig(withUart = true))
  }
}
