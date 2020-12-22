
import os
import parseopt
import options

import ./calcit_runner
import ./calcit_runner/errors
import ./calcit_runner/version

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
  of cmdArgument:
    snapshotFile = cliArgs.key
    dimEcho "Runner: specifying files", snapshotFile

if evalOnce:
  discard evalSnippet(evalOnceCode)
else:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(snapshotFile, initFn)
