
import os
import parseopt
import options

import ./calcit_runner
import ./calcit_runner/compiler_configs
import ./calcit_runner/util/color_echo

var evalOnce = false
var evalOnceCode: string
var initFn = none(string)

var snapshotFile = "compact.cirru"

echo "Running calcit runner(" & commandLineVersion & ") in CI mode"

var cliArgs = initOptParser(commandLineParams())

while true:
  cliArgs.next()
  case cliArgs.kind
  of cmdEnd: break
  of cmdShortOption:
    if cliArgs.key == "e":
      evalOnce = true
      evalOnceCode = cliArgs.val
      break
  of cmdLongOption:
    if cliArgs.key == "init-fn" and cliArgs.val != "":
      initFn = some(cliArgs.val)
    elif cliArgs.key == "emit-js":
      jsMode = true
    elif cliArgs.key == "emit-ir":
      irMode = true
    elif cliArgs.key == "mjs":
      mjsMode = true
  of cmdArgument:
    snapshotFile = cliArgs.key
    dimEcho "Runner: specifying files", snapshotFile

if evalOnce:
  discard evalSnippet(evalOnceCode)
else:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(snapshotFile, initFn)
