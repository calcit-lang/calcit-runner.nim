
import calcit_runner
import os
import tables

import cirru_edn
import edn_paint

import ./calcit_runner/watcher
import ./calcit_runner/compiler_configs
import ./calcit_runner/injection/canvas
import ./calcit_runner/injection/event_loop
import ./calcit_runner/util/color_echo

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

# reuse code
parseCliArgs()

if not (jsMode or irMode):
  registerCoreProc("init-canvas", nativeInitCanvas)
  registerCoreProc("draw-canvas", nativeDrawCanvas)
  registerCoreProc("draw-error-message", nativeDrawErrorMessage)
  registerCoreProc("timeout-call", nativeTimeoutCall)

if programEvalOnce:
  discard evalSnippet(programEvalOnceCode)
elif programRunOnce:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(programSnapshotFile, programInitFn)
else:
  echo "Calcit runner version: ", commandLineVersion
  discard runProgram(programSnapshotFile, programInitFn)
  # watch mode by default
  setControlCHook(handleControl)
  watchFile(programSnapshotFile, programIncrementFile)
