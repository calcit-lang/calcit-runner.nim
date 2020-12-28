
import os
import strutils
import lists
import json
import terminal
import tables
import options
import sets

import cirru_parser
import cirru_edn
import ternary_tree

import calcit_runner/types
import calcit_runner/core_syntax
import calcit_runner/core_func
import calcit_runner/core_abstract
import calcit_runner/errors
import calcit_runner/loader
import calcit_runner/stack
import calcit_runner/gen_data
import calcit_runner/evaluate
import calcit_runner/eval_util
import calcit_runner/gen_code
import calcit_runner/emit_js
import calcit_runner/color_echo

export CirruData, CirruDataKind, `==`, crData

# slots for dynamic registering GUI functions
var onLoadPluginProcs: Table[string, FnInData]

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!", pkg: "app")

proc registerCoreProc*(procName: string, f: FnInData) =
  onLoadPluginProcs[procName] = f

proc evaluateDefCode(ns: string, def: string, data: CirruData, dropArg: bool ): CirruData =
  let scope = CirruDataScope()
  preprocessSymbolByPath(ns, def)
  let entry = getEvaluatedByPath(ns, def, scope)

  if entry.kind != crDataFn:
    raise newException(ValueError, "expects a function at " & ns & "/" & def)

  let mainCode = programCode[ns].defs[def]
  defStack = initDoublyLinkedList[StackInfo]()
  pushDefStack StackInfo(ns: ns, def: def, code: mainCode)

  let args = if dropArg: @[] else: @[data]
  let ret = evaluteFnData(entry, args, interpret, ns)
  popDefStack()
  return ret

proc displayErrorMessage(message: string) =
  displayStackDetails(message)
  echo ""
  coloredEcho fgRed, message
  echo ""

  let ns = codeConfigs.initFn.split('/')[0]
  let def = "on-error"
  if programCode.hasKey(ns) and programCode[ns].defs.hasKey(def):
    discard evaluateDefCode(ns, def, CirruData(kind: crDataString, stringVal: message), false)

proc runCode(ns: string, def: string, argData: CirruData, dropArg: bool = false): CirruData =
  try:
    if jsMode:
      preprocessSymbolByPath(ns, def)
      emitJs(programData, ns, def)
    else:
      return evaluateDefCode(ns, def, argData, dropArg)

  except CirruEvalError as e:
    displayErrorMessage(e.msg & " " & $e.code)
    raise e

  except ValueError as e:
    displayErrorMessage(e.msg)
    raise e

  except Defect as e:
    displayErrorMessage("Failed assertion")
    raise e

# only load code of modules, ignore recursive deps
proc loadModules(modulePath: string) =
  let fullpath = getEnv("HOME").joinPath(".config/calcit/modules/", modulePath)
  echo "Loading module: ", fullpath
  let snapshotInfo = loadSnapshot(fullpath)

  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file

proc runProgram*(snapshotFile: string, initFn: Option[string] = none(string)): CirruData =
  let snapshotInfo = loadSnapshot(snapshotFile)

  for modulePath in snapshotInfo.configs.modules:
    loadModules(modulePath)

  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file
  codeConfigs = snapshotInfo.configs

  programData.clear()

  programCode[coreNs] = FileSource()
  programData[coreNs] = ProgramFile()

  loadCoreDefs(programData, interpret)
  loadCoreSyntax(programData, interpret)

  loadCoreFuncs(programCode)

  # register temp functions
  for procName, tempProc in onLoadPluginProcs:
    programData[coreNs].defs[procName] = CirruData(kind: crDataProc, procVal: tempProc)

  let pieces = if initFn.isSome:
    initFn.get.split("/")
  else:
   codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  runCode(pieces[0], pieces[1], CirruData(kind: crDataNil), true)

proc runEventListener*(event: CirruEdnValue) =
  let ns = codeConfigs.initFn.split('/')[0]
  let def = "on-window-event"

  if programCode.hasKey(ns).not or programCode[ns].defs.hasKey(def).not:
    echo "Warning: " & ns & "/" & def & "does not exist"
    return
  try:
    discard runCode(ns, def, event.toCirruData(ns, none(CirruDataScope)))

  except ValueError as e:
    coloredEcho fgRed, "Failed to handle event: ", e.msg
    # raise e

proc reloadProgram(snapshotFile: string): void =
  let previousCoreSource = programCode[coreNs]
  let snapshotInfo = loadSnapshot(snapshotFile)
  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file
  clearProgramDefs(programData, codeConfigs.pkg)
  programCode[coreNs] = previousCoreSource
  let pieces = codeConfigs.reloadFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  discard runCode(pieces[0], pieces[1], CirruData(kind: crDataNil), true)

proc handleFileChange*(snapshotFile: string, incrementFile: string): void =
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

proc evalSnippet*(code: string): CirruData =

  programCode[coreNs] = FileSource()
  programData[coreNs] = ProgramFile()

  loadCoreDefs(programData, interpret)
  loadCoreSyntax(programData, interpret)
  loadCoreFuncs(programCode)

  programCode["app.main"] = FileSource()
  programData["app.main"] = ProgramFile()

  let lines = parseEvalMain(code, "app.main")
  if lines.kind != crDatalist:
    raise newException(ValueError, "expects a list")
  let body = lines.listVal[0]
  let mainCode = generateMainCode(body, "app.main")
  programCode["app.main"].defs["main!"] = mainCode

  runCode("app.main", "main!", CirruData(kind: crDataNil), true)
