
import os
import strutils
import lists
import json
import terminal
import tables
import options
import parseopt
import sets

import cirru_parser
import cirru_edn
import ternary_tree
import libfswatch
import libfswatch/fswatch

import calcit_runner/types
import calcit_runner/core_syntax
import calcit_runner/core_func
import calcit_runner/core_abstract
import calcit_runner/errors
import calcit_runner/loader
import calcit_runner/stack
import calcit_runner/gen_data
import calcit_runner/evaluate

var runOnce = false

# slots for dynamic registering GUI functions
var tempProcsToLoad: Table[string, FnInData]

export CirruData, CirruDataKind, `==`, crData

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!")

proc registerCoreProc*(procName: string, f: FnInData) =
  tempProcsToLoad[procName] = f

proc runProgram*(snapshotFile: string, initFn: Option[string] = none(string)): CirruData =
  let snapshotInfo = loadSnapshot(snapshotFile)
  programCode = snapshotInfo.files
  codeConfigs = snapshotInfo.configs

  programData.clear

  programCode[coreNs] = FileSource()
  programData[coreNs] = ProgramFile()

  loadCoreDefs(programData, interpret)
  loadCoreSyntax(programData, interpret)

  loadCoreFuncs(programCode)

  # register temp functions
  for procName, tempProc in tempProcsToLoad:
    programData[coreNs].defs[procName] = CirruData(kind: crDataProc, procVal: tempProc)

  let scope = CirruDataScope()

  let pieces = if initFn.isSome:
    initFn.get.split("/")
  else:
   codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  try:
    preprocessSymbolByPath(pieces[0], pieces[1])
    let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

    if entry.kind != crDataFn:
      raise newException(ValueError, "expects a function at app.main/main!")

    let mainCode = programCode[pieces[0]].defs[pieces[1]]
    defStack = initDoublyLinkedList[StackInfo]()
    pushDefStack StackInfo(ns: pieces[0], def: pieces[1], code: mainCode)

    var ret = CirruData(kind: crDataNil)
    for child in entry.fnCode:
      ret = interpret(child, scope)

    return ret

  except CirruEvalError as e:
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.code
    showStack()
    echo ""
    raise e

  except CirruCoreError as e:
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.data
    showStack()
    echo ""
    raise e

proc reloadProgram(snapshotFile: string): void =
  let previousCoreSource = programCode[coreNs]
  programCode = loadSnapshot(snapshotFile).files
  clearProgramDefs(programData)
  programCode[coreNs] = previousCoreSource
  var scope: CirruDataScope

  let pieces = codeConfigs.reloadFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  try:
    preprocessSymbolByPath(pieces[0], pieces[1])
    let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

    if entry.kind != crDataFn:
      raise newException(ValueError, "expects a function at app.main/main!")

    let mainCode = programCode[pieces[0]].defs[pieces[1]]
    defStack = initDoublyLinkedList[StackInfo]()
    pushDefStack StackInfo(ns: pieces[0], def: pieces[1], code: mainCode)

    var ret = CirruData(kind: crDataNil)
    for child in entry.fnCode:
      ret = interpret(child, scope)

  except CirruEvalError as e:
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.code
    showStack()
    echo ""
    raise e

  except CirruCoreError as e:
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.data
    showStack()
    echo ""
    raise e

proc watchFile(snapshotFile: string, incrementFile: string): void =
  if not existsFile(incrementFile):
    writeFile incrementFile, "{}"

  let fileChangeCb = proc (event: fsw_cevent, event_num: cuint): void =
    sleep 150
    coloredEcho fgYellow, "\n-------- file change --------\n"
    loadChanges(incrementFile, programCode)
    try:
      reloadProgram(snapshotFile)
    except ValueError as e:
      coloredEcho fgRed, "Failed to rerun program: ", e.msg

    except CirruParseError as e:
      coloredEcho fgRed, "\nError: failed to parse"
      echo e.msg

    except CirruCommandError as e:
      coloredEcho fgRed, "Failed to run command"
      echo e.msg

  dimEcho "\nRunner: in watch mode...\n"

  var mon = newMonitor()
  discard mon.handle.fsw_set_latency 0.2
  mon.addPath(incrementFile)
  mon.setCallback(fileChangeCb)
  mon.start()

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc main*(): void =
  var cliArgs = initOptParser(commandLineParams())
  var snapshotFile = "compact.cirru"
  var incrementFile = ".compact-inc.cirru"

  while true:
    cliArgs.next()
    case cliArgs.kind
    of cmdEnd: break
    of cmdShortOption:
      if cliArgs.key == "1":
        if cliArgs.val == "" or cliArgs.val == "true":
          runOnce = true
          dimEcho "Runner: watching mode disabled."
    of cmdLongOption:
      if cliArgs.key == "once":
        if cliArgs.val == "" or cliArgs.val == "true":
          runOnce = true
          dimEcho "Runner: watching mode disabled."
    of cmdArgument:
      snapshotFile = cliArgs.key
      incrementFile = cliArgs.key.replace("compact", ".compact-inc")
      dimEcho "Runner: specifying files", snapshotFile, incrementFile

  discard runProgram(snapshotFile)

  if not runOnce:
    setControlCHook(handleControl)
    watchFile(snapshotFile, incrementFile)
