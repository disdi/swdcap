package swdcap

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.com.swd.sim._

/**
 * SwdcapTop driven over the real SWD wire protocol by the upstream host model. SWCLK is
 * bit-banged by the bench and the debug clock free-runs, so the two are asynchronous and every
 * DMI access crosses the gateway's CDC. Helpers retry on WAIT, as a host does.
 *
 * One SWCLK cycle is 4 time units, so debugPeriod 10 is a debug clock slower than SWCLK and
 * debugPeriod 2 a faster one.
 */
class SwdHarness(val dut: SwdcapTop, debugPeriod: Int) {
  import SwdAckSim._

  val swdCd = ClockDomain(dut.io.swclk)
  val drv   = new SwdHostDriver(swdCd, dut.io.swdio_i, dut.io.swdio_o, dut.io.swdio_oe)

  def start(): Unit = {
    dut.io.swclk   #= false
    dut.io.swdio_i #= false
    dut.clockDomain.forkStimulus(period = debugPeriod)
    dut.clockDomain.waitSampling(10)          // debug reset released
    drv.lineReset()                           // what a host does first
  }

  def dpRead(addr: Int): (Int, Option[BigInt]) = drv.transactRead(apNdp = false, addr)
  def dpWrite(addr: Int, data: BigInt): Int    = drv.transactWrite(apNdp = false, addr, data)

  def ctrlStat: BigInt = {
    val (ack, data) = dpRead(1)
    assert(ack == OK, s"CTRL/STAT unreadable, ack=$ack")
    data.get
  }
  def stickyErr: Boolean = ctrlStat.testBit(5)
  def abortStickyErr(): Unit = assert(dpWrite(0, 1 << 2) == OK, "ABORT write refused")

  /** Poll RDBUFF until the outstanding access completes. Left(FAULT) when it ended in an error. */
  def rdbuff(max: Int = 400): Either[Int, BigInt] = {
    var tries = 0
    while (tries < max) {
      val (ack, data) = dpRead(3)
      if (ack == OK) return Right(data.get)
      if (ack == FAULT) return Left(FAULT)
      assert(ack == WAIT, s"unexpected ack=$ack on RDBUFF")
      tries += 1
      drv.idle(2)
    }
    throw new AssertionError("RDBUFF never completed")
  }

  def apWrite(addr: Int, data: BigInt, max: Int = 400): Int = {
    var tries = 0
    while (tries < max) {
      val ack = drv.transactWrite(apNdp = true, addr, data)
      if (ack != WAIT) return ack
      tries += 1
      drv.idle(2)
    }
    throw new AssertionError(s"AP write @$addr never accepted")
  }

  def apReadLaunch(addr: Int, max: Int = 400): Int = {
    var tries = 0
    while (tries < max) {
      val (ack, _) = drv.transactRead(apNdp = true, addr)
      if (ack != WAIT) return ack
      tries += 1
      drv.idle(2)
    }
    throw new AssertionError(s"AP read @$addr never accepted")
  }

  def apRead(addr: Int): BigInt = {
    assert(apReadLaunch(addr) == OK, s"AP read @$addr refused")
    rdbuff().right.get
  }

  /** DMI read. Right(data), or Left(FAULT) when the access returned an error (STICKYERR set). */
  def dmiRead(address: Long): Either[Int, BigInt] = {
    assert(apWrite(1, address) == OK, "DMI_ADDR write refused")
    assert(apReadLaunch(2) == OK, "DMI_DATA read refused")
    rdbuff()
  }

  /** DMI write. Returns true when it completed without an error. */
  def dmiWrite(address: Long, data: BigInt): Boolean = {
    assert(apWrite(1, address) == OK, "DMI_ADDR write refused")
    assert(apWrite(2, data) == OK, "DMI_DATA write refused")
    rdbuff().isRight                          // waits for completion; FAULT if it errored
  }

  def read(address: Long): BigInt = dmiRead(address) match {
    case Right(v) => v
    case Left(_)  => throw new AssertionError(f"DMI read of 0x$address%04x returned an error")
  }

  /** Assert that a read errors, then recover the way a host does. */
  def expectReadError(address: Long): Unit = {
    assert(dmiRead(address).isLeft, f"DMI read of 0x$address%04x must return an error")
    assert(stickyErr, "STICKYERR must be set after a DMI error")
    abortStickyErr()
    assert(!stickyErr, "ABORT must clear STICKYERR")
  }

  def expectWriteError(address: Long): Unit = {
    assert(!dmiWrite(address, 0x12345678), f"DMI write of 0x$address%04x must return an error")
    assert(stickyErr, "STICKYERR must be set after a DMI error")
    abortStickyErr()
  }

  def dmiAddrWidth: Int = {
    assert(apWrite(1, BigInt("FFFFFFFF", 16)) == OK)
    apRead(1).bitLength
  }
}

abstract class SwdcapTopSimBase(name: String, c: SwdcapConfig) extends AnyFunSuite {
  import SwdcapRegs._
  import SwdAckSim._

  lazy val compiled = SimConfig.withConfig(SpinalConfig(targetDirectory = "simWorkspace/rtl"))
    .workspacePath("simWorkspace").workspaceName(name).compile(SwdcapTop(c))

  def sim(what: String, debugPeriod: Int = 10)(body: SwdHarness => Unit): Unit = test(s"$name: $what") {
    compiled.doSim(what.replaceAll("[^A-Za-z0-9]+", "_")) { dut =>
      val h = new SwdHarness(dut, debugPeriod)
      h.start()
      body(h)
    }
  }

  val scratchMask = (BigInt(1) << c.scratchWidth) - 1

  /** The P1 exit sequence: identify, read the ID window, exercise scratch. */
  def identify(h: SwdHarness): Unit = {
    val (ack, dpidr) = h.dpRead(0)
    assert(ack == OK && dpidr.contains(DPIDR), "DPIDR")
    assert(h.apRead(0) == AP_IDR, "AP_IDR")
    assert(h.read(ID_MAGIC) == MAGIC, "MAGIC")
    assert(h.read(ID_VERSION) == VERSION, "VERSION")
    assert(h.read(ID_FEATURES) == c.features, "FEATURES")
    assert(h.read(ID_DEBUG_CLK_HZ) == BigInt(c.debugClkHz), "DEBUG_CLK_HZ")
    assert(h.read(ID_EIO_WIDTH) == c.eioWidthReg, "EIO_WIDTH")
    assert(h.read(ID_ELA_WIDTH) == 0 && h.read(ID_ELA_DEPTH) == 0, "ELA_WIDTH / ELA_DEPTH")
    assert(h.read(ID_SCRATCH) == 0, "SCRATCH resets to 0")
    for (v <- Seq(BigInt("A5A5A5A5", 16), BigInt("5A5A5A5A", 16), BigInt("FFFFFFFF", 16), BigInt(0))) {
      assert(h.dmiWrite(ID_SCRATCH, v), "SCRATCH write")
      assert(h.read(ID_SCRATCH) == (v & scratchMask), "SCRATCH read-back")
    }
  }

  sim("identify, ID window and scratch, debug clock slower than SWCLK", debugPeriod = 10)(identify)
  sim("identify, ID window and scratch, debug clock faster than SWCLK", debugPeriod = 2)(identify)
  sim("identify, ID window and scratch, debug clock much slower than SWCLK", debugPeriod = 97)(identify)

  sim("DMI_ADDR stores exactly addressWidth bits") { h =>
    assert(h.dmiAddrWidth == c.addressWidth)
  }

  sim("the DM range reads 0 without an error and ignores writes") { h =>
    for (a <- Seq(0x00, 0x10, 0x11, 0x7F)) assert(h.read(a) == 0)
    assert(h.dmiWrite(0x10, 1), "a write to the DM range must not error")
    assert(h.read(0x10) == 0)
    assert(!h.stickyErr)
  }

  sim("a write to a read-only ID register is ignored without an error") { h =>
    assert(h.dmiWrite(ID_MAGIC, 0))
    assert(h.read(ID_MAGIC) == MAGIC)
    assert(!h.stickyErr)
  }

  sim("unmapped words and windows that are not generated return an error, and ABORT recovers") { h =>
    // Each of these is addressable with addressWidth = 10. FEATURES, not the address, says
    // whether a window exists.
    for (a <- Seq(0x0080, 0x00FF, ID_SCRATCH + 1, 0x01FF, EIO_BASE, EIO_OUT, 0x02FF, ELA_BASE, 0x03FF)) {
      h.expectReadError(a)
      assert(h.read(ID_MAGIC) == MAGIC, "the next access after ABORT must work")
    }
    h.expectWriteError(ELA_BASE)
    assert(h.read(ID_MAGIC) == MAGIC)
  }

  sim("a sticky error blocks AP accesses with FAULT until ABORT") { h =>
    assert(h.dmiRead(ELA_BASE).isLeft)
    assert(h.apReadLaunch(0) == FAULT)
    assert(h.apWrite(1, ID_MAGIC) == FAULT)
    h.abortStickyErr()
    assert(h.read(ID_MAGIC) == MAGIC)
  }

  sim("a line reset in the middle of a session keeps the link usable") { h =>
    assert(h.dmiWrite(ID_SCRATCH, BigInt("CAFEF00D", 16)))
    h.drv.lineReset()
    val (ack, dpidr) = h.dpRead(0)
    assert(ack == OK && dpidr.contains(DPIDR))
    assert(h.read(ID_SCRATCH) == (BigInt("CAFEF00D", 16) & scratchMask), "line reset must not touch the instruments")
  }
}

/** FPGA shape: 16-bit DMI address, BOOT-reset SWCLK domain. */
class SwdcapTopFpgaSim extends SwdcapTopSimBase("fpga", SwdcapConfig(withEio = false)) {
  import SwdcapRegs._

  sim("the reserved windows beyond 10 bits return an error") { h =>
    for (a <- Seq(WB_BASE, UART_BASE, 0x0600, 0x7FFF, ELA_RAM_BASE, 0xFFFF)) {
      h.expectReadError(a)
    }
    assert(h.read(ID_MAGIC) == MAGIC)
  }
}

/** Tiny Tapeout shape: 10-bit DMI address, SWCLK domain reset from the debug reset, narrow scratch. */
class SwdcapTopSiliconSim extends SwdcapTopSimBase("silicon",
    SwdcapConfig.tinyTapeout.copy(withEio = false, scratchWidth = 8)) {
  import SwdcapRegs._
  import SwdAckSim._

  sim("addresses beyond 10 bits alias into the low range") { h =>
    // 0x0400 truncates to 0x0000 (DM range, reads 0) and 0x0500 to 0x0100 (MAGIC). This is why
    // the host reads the DMI_ADDR width and refuses wider addresses.
    assert(h.read(0x0400) == 0)
    assert(h.read(0x0500) == MAGIC)
  }

  sim("the debug reset also resets the SWD side") { h =>
    assert(h.dmiWrite(ID_SCRATCH, 0x5A))
    assert(h.dmiRead(ELA_BASE).isLeft && h.stickyErr, "leave STICKYERR set")
    assert(h.dpWrite(2, BigInt("FF0000F0", 16)) == OK, "leave SELECT non-zero")

    h.dut.clockDomain.assertReset()
    sleep(50)
    h.dut.clockDomain.deassertReset()
    h.dut.clockDomain.waitSampling(4)
    h.drv.lineReset()

    assert(!h.stickyErr, "reset must clear STICKYERR without an ABORT")
    assert(h.read(ID_MAGIC) == MAGIC)
    assert(h.read(ID_SCRATCH) == 0, "reset must clear SCRATCH")
  }
}
