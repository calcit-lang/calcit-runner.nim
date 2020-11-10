
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
requires "https://github.com/Cirru/cirru-edn.nim#v0.3.4"
requires "ternary_tree >= 0.1.27"
requires "https://github.com/Quamolit/json-paint.nim#v0.0.8"

task watch, "run and watch":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr example/compact.cirru"

task once, "run once":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr --once example/compact.cirru"

task perf, "run with perf":
  exec "nim compile --verbosity:0 --profiler:on --stackTrace:on --hints:off --threads:on -r tests/prof --once tests/snapshots/fibo.cirru"

task t, "Runs the test suite":
  exec "nim c -r --hints:off --threads:on tests/test_expr.nim"

task tg, "test gynienic macro":
  exec "nim c -r --hints:off --threads:on tests/test_gynienic.nim"

task ct, "Runs calcit tests":
  exec "nim c -r --hints:off --threads:on tests/run_calcit.nim"

task e, "eval some code":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr -e='echo 1'"
