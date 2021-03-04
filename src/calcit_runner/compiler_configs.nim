
import os
import parseopt
import options
import strutils

# calcit-runner is used for both evaling and compiling to js
# configs collected in order to expose to whole program

let commandLineVersion* = "0.2.80"

# dirty states controlling js backend
var jsMode* = false
var mjsMode* = false # TODO not working correctly now

var irMode* = false

var codeEmitPath* = "js-out"

var programInitFn* = none(string)
var programReloadFn* = none(string)

var programRunOnce* = false
var programEvalOnce* = false
var programEvalOnceCode*: string

var programSnapshotFile* = "compact.cirru"
var programIncrementFile* = ".compact-inc.cirru"

proc parseCliArgs*(): void =
  var cliArgs = initOptParser(commandLineParams())

  while true:
    cliArgs.next()
    case cliArgs.kind
    of cmdEnd: break
    of cmdShortOption:
      if cliArgs.key == "e":
        programEvalOnce = true
        programEvalOnceCode = cliArgs.val
        break
    of cmdLongOption:
      if cliArgs.key == "once":
        programRunOnce = true
        echo "Runner: run-noce mode."
      elif cliArgs.key == "init-fn" and cliArgs.val != "":
        programInitFn = some(cliArgs.val)
      elif cliArgs.key == "reload-fn" and cliArgs.val != "":
        programReloadFn = some(cliArgs.val)
      elif cliArgs.key == "emit-js":
        jsMode = true
      elif cliArgs.key == "emit-ir":
        irMode = true
      elif cliArgs.key == "mjs":
        mjsMode = true
      elif cliArgs.key == "emit-path":
        codeEmitPath = cliArgs.val
      else:
        raise newException(OSError, "Unknown option: " & cliArgs.key)
    of cmdArgument:
      programSnapshotFile = cliArgs.key
      # guessed...
      programIncrementFile = cliArgs.key.replace("compact.cirru", ".compact-inc.cirru")
      echo "Runner: specifying files", programSnapshotFile
