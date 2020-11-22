
import json
import calcit_runner
import parseopt
import os
import strutils

import json_paint

import ./calcit_runner/canvas
import ./calcit_runner/watcher
import ./calcit_runner/errors

var runOnce = false
var evalOnce = false
var evalOnceCode: string

registerCoreProc("init-canvas", nativeInitCanvas)
registerCoreProc("draw-canvas", nativeDrawCanvas)
registerCoreProc("draw-error-message", nativeDrawErrorMessage)

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc watchFile(snapshotFile: string, incrementFile: string): void =
  if not fileExists(incrementFile):
    writeFile incrementFile, "{}"

  watchingChan.open()

  var theWatchingTask: Thread[string]
  createThread(theWatchingTask, watchingTask, incrementFile)
  # disabled since task blocking
  # joinThreads(@[theWatchingTask])

  dimEcho "\nRunner: in watch mode...\n"

  while true:
    let tried = watchingChan.tryRecv()
    if tried.dataAvailable:
      # echo tried.msg
      handleFileChange(snapshotFile, incrementFile)

    takeCanvasEvents(proc(event: JsonNode) =
      if event.kind == JObject:
        case event["type"].getStr
        of "quit":
          quit 0
        else:
          runEventListener(event)
    )

    sleep(180)

var cliArgs = initOptParser(commandLineParams())
var snapshotFile = "compact.cirru"
var incrementFile = ".compact-inc.cirru"

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
    if cliArgs.key == "once":
      if cliArgs.val == "" or cliArgs.val == "true":
        runOnce = true
        dimEcho "Runner: watching mode disabled."
  of cmdArgument:
    snapshotFile = cliArgs.key
    incrementFile = cliArgs.key.replace("compact", ".compact-inc")
    dimEcho "Runner: specifying files", snapshotFile, incrementFile

if evalOnce:
  discard evalSnippet(evalOnceCode)
elif runOnce:
  discard runProgram(snapshotFile)
else:
  discard runProgram(snapshotFile)
  # watch mode by default
  setControlCHook(handleControl)
  watchFile(snapshotFile, incrementFile)
