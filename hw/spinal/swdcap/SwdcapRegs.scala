package swdcap

/**
 * The frozen v0.1 register contract. docs/regmap.md is the readable form of this file; keep the
 * two in step. All addresses are DMI word addresses (what the host writes to DMI_ADDR).
 */
object SwdcapRegs {
  // Transport identity, inherited unchanged from the SpinalHDL SWD DMI gateway
  val DPIDR  = BigInt("0BA11AAB", 16)
  val AP_IDR = BigInt("74726976", 16)

  // "SWDC" as little-endian bytes
  val MAGIC = BigInt("43445753", 16)

  // VERSION: major[31:16] minor[15:8] patch[7:0]
  val VERSION_MAJOR = 0
  val VERSION_MINOR = 1
  val VERSION_PATCH = 0
  val VERSION = (BigInt(VERSION_MAJOR) << 16) | (VERSION_MINOR << 8) | VERSION_PATCH

  // 0x0000-0x007F: reserved for a RISC-V Debug Module. Reads 0, writes ignored, no error.
  val DM_FIRST = 0x0000
  val DM_LAST  = 0x007F

  // ID window
  val ID_BASE         = 0x0100
  val ID_MAGIC        = ID_BASE + 0
  val ID_VERSION      = ID_BASE + 1
  val ID_FEATURES     = ID_BASE + 2
  val ID_DEBUG_CLK_HZ = ID_BASE + 3
  val ID_EIO_WIDTH    = ID_BASE + 4
  val ID_ELA_WIDTH    = ID_BASE + 5
  val ID_ELA_DEPTH    = ID_BASE + 6
  val ID_SCRATCH      = ID_BASE + 7

  // EIO window
  val EIO_BASE = 0x0200
  val EIO_IN   = EIO_BASE + 0
  val EIO_OUT  = EIO_BASE + 1

  // Reserved windows: an access returns an error (STICKYERR) until the instrument is generated
  val ELA_BASE     = 0x0300
  val WB_BASE      = 0x0400
  val UART_BASE    = 0x0500
  val ELA_RAM_BASE = 0x8000

  // FEATURES bits
  val FEATURE_EIO     = 0
  val FEATURE_ELA     = 1
  val FEATURE_UART    = 2
  val FEATURE_BUS_WB  = 3
  val FEATURE_BUS_AXI = 4
  val FEATURE_DM      = 5

  // The smallest DMI address width that still reaches the ID and EIO windows
  val MIN_ADDRESS_WIDTH = 10
}
