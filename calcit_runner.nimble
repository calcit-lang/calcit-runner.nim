
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
requires "https://github.com/Cirru/cirru-edn.nim#v0.3.1"
requires "https://github.com/Cirru/ternary-tree#v0.1.14"

task watch, "run and watch":
  exec "nim compile --verbosity:0 --hints:off -r src/cr example/compact.cirru"

task once, "run once":
  exec "nim compile --verbosity:0 --hints:off -r src/cr --once example/compact.cirru"

task perf, "run with perf":
  exec "nim compile --verbosity:0 --profiler:on --stackTrace:on --hints:off -r tests/prof --once tests/snapshots/fibo.cirru"

task t, "Runs the test suite":
  exec "nim c -r --hints:off tests/test_expr.nim"

task ct, "Runs calcit tests":
  exec "nim c -r --hints:off tests/run_calcit.nim"
