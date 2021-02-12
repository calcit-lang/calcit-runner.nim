
# Package

version       = "0.2.58"
author        = "jiyinyiyong"
description   = "Script runner for Cirru"
license       = "MIT"
srcDir        = "src"
namedBin      = {"cr": "cr", "cr_once": "cr_once"}.toTable()
binDir        = "out/"

# Dependencies

requires "nim >= 1.2.8"
requires "libfswatch"
requires "nanoid"
requires "cirru_parser >= 0.3.0"
requires "ternary_tree >= 0."
requires "https://github.com/Cirru/cirru-edn.nim#v0.4.3"
requires "https://github.com/calcit-lang/edn-paint#v0.2.7"
requires "https://github.com/dual-balanced-ternary/dual-balanced-ternary.nim#v0.0.4"

task watch, "run and watch":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr example/compact.cirru"

task once, "run once":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr --once example/compact.cirru"

task perf, "run with perf":
  # exec "nim compile --profiler:on --stackTrace:on -r tests/prof"
  exec "nim compile --profiler:on --stackTrace:on -r tests/large_json"

task t, "Runs the test suite":
  exec "nim c -r --hints:off --threads:on tests/test_expr.nim"

task tg, "test gynienic macro":
  exec "nim c -r --hints:off --threads:on tests/test_gynienic.nim"

task ct, "Runs calcit tests":
  exec "nim c -r --hints:off --threads:on tests/run_calcit.nim"

task e, "eval some code":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr -e='range 10'"

task genjs, "try generating js":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr_once --emit-js tests/snapshots/test.cirru --once"
  # exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr --emit-js example/compact.cirru --once"

task genir, "try generating ir":
  exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr_once --emit-ir tests/snapshots/test.cirru --once"
  # exec "nim compile --verbosity:0 --hints:off --threads:on -r src/cr --emit-js example/compact.cirru --once"
