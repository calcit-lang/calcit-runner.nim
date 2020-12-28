
import calcit_runner
import parseopt
import os
import strutils
import options
import tables

import cirru_edn
import edn_paint

import ./calcit_runner/canvas
import ./calcit_runner/watcher
import ./calcit_runner/errors
import ./calcit_runner/version
import ./calcit_runner/event_loop
import ./calcit_runner/emit_js

var runOnce = false
var evalOnce = false
var evalOnceCode: string
var initFn = none(string)

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

    takeCanvasEvents(proc(event: CirruEdnValue) =
      if event.kind == crEdnMap:
        let t = event.mapVal[genCrEdnKeyword("type")]
        if t.kind != crEdnKeyword:
          raise newException(ValueError, "expects event type in keyword")
        case t.keywordVal
        of "quit":
          quit 0
        else:
          runEventListener(event)
    )

    let triedEvent = eventsChan.tryRecv()
    if triedEvent.dataAvailable:
      let taskParams = triedEvent.msg
      finishTask(taskParams.id, taskParams.params)

    sleep(90)

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
    if cliArgs.key == "init-fn" and cliArgs.val != "":
      initFn = some(cliArgs.val)
    if cliArgs.key == "emit-js":
      jsMode = true
  of cmdArgument:
    snapshotFile = cliArgs.key
    incrementFile = cliArgs.key.replace("compact", ".compact-inc")
    dimEcho "Runner: specifying files", snapshotFile, incrementFile

if evalOnce:
  discard evalSnippet(evalOnceCode)
elif runOnce:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(snapshotFile, initFn)
else:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(snapshotFile, initFn)
  # watch mode by default
  setControlCHook(handleControl)
  watchFile(snapshotFile, incrementFile)
