
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
import calcit_runner/to_json
import calcit_runner/gen_code

# slots for dynamic registering GUI functions
var onLoadPluginProcs: Table[string, FnInData]

export CirruData, CirruDataKind, `==`, crData

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!", pkg: "app")

proc registerCoreProc*(procName: string, f: FnInData) =
  onLoadPluginProcs[procName] = f

proc runCode(ns: string, def: string, data: CirruData, dropArg: bool = false): CirruData =
  let scope = CirruDataScope()

  try:
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

  except CirruEvalError as e:
    showStack()
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.code
    echo ""
    raise e

  except CirruCoreError as e:
    echo ""
    coloredEcho fgRed, e.msg, " ", $e.data
    showStack()
    echo ""
    raise e

  except ValueError as e:
    echo ""
    coloredEcho fgRed, e.msg
    showStack()
    echo ""
    raise e

  except Defect as e:
    coloredEcho fgRed, "Failed to run command"
    echo e.msg

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

proc runEventListener*(event: JsonNode) =
  let ns = codeConfigs.initFn.split('/')[0]
  let def = "on-window-event"

  if programCode.hasKey(ns).not or programCode[ns].defs.hasKey(def).not:
    echo "Warning: " & ns & "/" & def & "does not exist"
    return
  try:
    discard runCode(ns, def, event.toCirruData)

  except ValueError as e:
    coloredEcho fgRed, "Failed to handle event: ", e.msg

proc reloadProgram(snapshotFile: string): void =
  let previousCoreSource = programCode[coreNs]
  programCode = loadSnapshot(snapshotFile).files
  clearProgramDefs(programData)
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

  except CirruCommandError as e:
    coloredEcho fgRed, "Failed to run command"
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
