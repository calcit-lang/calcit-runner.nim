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
requires "cirru-parser >= 0.0.5"
requires "cirru-edn >= 0.10"


task cr, "Try cr command":
  exec "nim compile --verbosity:0 --hints:off -r src/cr"

task t, "Runs the test suite":
  exec "nim c -r --hints:off tests/testExpr.nim"
