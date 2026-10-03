package swdcap

/**
 * Generator options. The defaults are the FPGA build; SwdcapConfig.tinyTapeout is the silicon
 * wrapper's configuration.
 *
 * @param addressWidth  DMI word-address width (DMI_ADDR bits). 10 is the minimum that reaches EIO.
 * @param swdAsyncReset false: the SWCLK domain is BOOT-reset (FPGA bitstream initialisation), as
 *                      upstream. true: it is reset asynchronously from the debug reset (silicon).
 * @param eioInWidth    number of EIO input bits, 1 to 32
 * @param eioOutWidth   number of EIO output bits, 1 to 32
 * @param scratchWidth  implemented bits of the ID SCRATCH register, 1 to 32
 * @param debugClkHz    debug (instrument) clock frequency reported in DEBUG_CLK_HZ; 0 = unknown
 */
case class SwdcapConfig(
  addressWidth:  Int     = 16,
  swdAsyncReset: Boolean = false,
  withEio:       Boolean = true,
  withEla:       Boolean = false,
  withWb:        Boolean = false,
  withUart:      Boolean = false,
  eioInWidth:    Int     = 8,
  eioOutWidth:   Int     = 8,
  scratchWidth:  Int     = 32,
  debugClkHz:    Long    = 0
) {
  import SwdcapRegs._

  require(addressWidth >= MIN_ADDRESS_WIDTH && addressWidth <= 32,
    s"addressWidth must be $MIN_ADDRESS_WIDTH to 32, got $addressWidth")
  require(eioInWidth >= 1 && eioInWidth <= 32, s"eioInWidth must be 1 to 32, got $eioInWidth")
  require(eioOutWidth >= 1 && eioOutWidth <= 32, s"eioOutWidth must be 1 to 32, got $eioOutWidth")
  require(scratchWidth >= 1 && scratchWidth <= 32, s"scratchWidth must be 1 to 32, got $scratchWidth")
  require(debugClkHz >= 0 && debugClkHz <= 0xFFFFFFFFL, s"debugClkHz must fit 32 bits, got $debugClkHz")
  // v0.1 guard. Remove the matching term when that instrument is implemented (ELA: P3,
  // Wishbone bridge: P4, UART: P5).
  require(!withEla && !withWb && !withUart, "ELA, the Wishbone bridge and UART are not implemented in v0.1")

  /** Value of the FEATURES register. */
  def features: BigInt = Seq(
    withEio  -> FEATURE_EIO,
    withEla  -> FEATURE_ELA,
    withUart -> FEATURE_UART,
    withWb   -> FEATURE_BUS_WB
  ).collect { case (true, bit) => BigInt(1) << bit }.foldLeft(BigInt(0))(_ | _)

  /** Value of the EIO_WIDTH register: out[15:8], in[7:0]; 0 when EIO is not generated. */
  def eioWidthReg: BigInt =
    if (withEio) (BigInt(eioOutWidth) << 8) | eioInWidth else BigInt(0)

  /**
   * True when a DMI word address fits in addressWidth bits. This says nothing about whether a
   * window exists there: on the Tiny Tapeout build 0x0300 fits in 10 bits and still returns an
   * error. Whether an instrument exists is FEATURES, not this.
   */
  def reaches(address: Int): Boolean = address >= 0 && BigInt(address) < (BigInt(1) << addressWidth)
}

object SwdcapConfig {
  /** FPGA build: 16-bit DMI address, BOOT-reset SWCLK domain. */
  def fpga: SwdcapConfig = SwdcapConfig()

  /** Tiny Tapeout wrapper: 10-bit DMI address, SWCLK domain reset from rst_n, 8 in / 8 out. */
  def tinyTapeout: SwdcapConfig = SwdcapConfig(addressWidth = 10, swdAsyncReset = true)
}
