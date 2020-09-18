
# Package

version       = "0.0.1"
author        = "jiyinyiyong"
description   = "Script runner for Cirru"
license       = "MIT"
srcDir        = "src"
bin           = @["cr"]
binDir        = "out/"



# Dependencies

requires "nim >= 0.20.0"
requires "libfswatch"
requires "https://github.com/Cirru/cirru-edn.nim#v0.2.0"


task watch, "run and watch":
  exec "nim compile --verbosity:0 --hints:off -r src/cr example/compact.cirru"

task once, "run once":
  exec "nim compile --verbosity:0 --hints:off -r src/cr --once example/compact.cirru"

task t, "Runs the test suite":
  exec "nim c -r --hints:off tests/testExpr.nim"
