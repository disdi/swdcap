// swdcap builds against SpinalHDL from source. The submodule ext/SpinalHDL is pinned to
// 90b7d8eee (SpinalHDL#1966), the first commit that has spinal.lib.com.swd. Set SPINALHDL_PATH
// to use another checkout at that commit or later.
val spinalHdlPath = sys.env.getOrElse("SPINALHDL_PATH", "./ext/SpinalHDL")

lazy val spinalHdlIdslPlugin = ProjectRef(file(spinalHdlPath), "idslplugin")
lazy val spinalHdlSim        = ProjectRef(file(spinalHdlPath), "sim")
lazy val spinalHdlCore       = ProjectRef(file(spinalHdlPath), "core")
lazy val spinalHdlLib        = ProjectRef(file(spinalHdlPath), "lib")

lazy val root = (project in file("."))
  .settings(
    name         := "swdcap",
    organization := "io.github.disdi",
    version      := "0.1.0",
    scalaVersion := "2.12.18",
    Compile / scalaSource := baseDirectory.value / "hw" / "spinal",
    Test / scalaSource    := baseDirectory.value / "hw" / "test",
    scalacOptions += s"-Xplugin:${(spinalHdlIdslPlugin / Compile / packageBin).value.getAbsolutePath}",
    scalacOptions += "-Xplugin-require:idsl-plugin",
    libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.17" % Test,
    fork := true
  )
  .dependsOn(spinalHdlIdslPlugin, spinalHdlSim, spinalHdlCore, spinalHdlLib)
