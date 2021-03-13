
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
import calcit_runner/compiler_configs
import calcit_runner/core_syntax
import calcit_runner/core_func
import calcit_runner/util/errors
import calcit_runner/loader
import calcit_runner/util/stack
import calcit_runner/evaluate
import calcit_runner/eval/arguments
import calcit_runner/codegen/gen_code
import calcit_runner/codegen/emit_js
import calcit_runner/codegen/emit_ir
import calcit_runner/util/color_echo
import calcit_runner/data/to_edn
import calcit_runner/data/virtual_list

export CirruData, CirruDataKind, `==`

const coreSource = staticRead"./includes/calcit-core.cirru"

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

proc loadCoreFuncs*(programCode: var Table[string, FileSource]) =
  let initialData = parseCirruEdn coreSource

  if initialData.kind != crEdnMap: raise newException(ValueError, "expects a map from calcit-core.cirru")
  let files = initialData.get(genCrEdnKeyword("files"))

  if files.kind != crEdnMap: raise newException(ValueError, "expects a map in :files of calcit-core.cirru")
  for k, v in files.mapVal:
    if k.kind != crEdnString:
      raise newException(ValueError, "expects a string")
    for defName, defCode in extractFile(v, k.stringVal).defs:
      programCode[k.stringVal].defs[defName] = defCode

proc runCode(ns: string, def: string, argData: CirruData, dropArg: bool = false): CirruData =
  try:
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

proc emitCode(initFn, reloadFn: string): void =
  let initPair = initFn.split('/')
  let reloadPair = reloadFn.split('/')
  if initPair.len != 2:
    echo "Unknown initFn", initFn
    raise newException(ValueError, "Unknown initFn")
  if reloadPair.len != 2:
    echo "Unknown reloadFn", reloadFn
    raise newException(ValueError, "Unknown reloadFn")
  try:
    preprocessSymbolByPath(initPair[0], initPair[1])
    preprocessSymbolByPath(reloadPair[0], reloadPair[1])

    if irMode:
      emitIR(programData, initFn, reloadFn)

    if jsMode:
      emitJs(programData, initPair[0])
    else:
      raise newException(ValueError, "Unknown mode")
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
proc loadModules(modulePath: string, baseDir: string) =
  var fullpath: string
  if modulePath.startsWith("./"):
    fullpath = baseDir.joinPath(modulePath)
  elif modulePath.startsWith("/"):
    fullpath = modulePath
  else:
    fullpath = getEnv("HOME").joinPath(".config/calcit/modules/", modulePath)
  if fullpath.endsWith("/"):
    fullpath = fullpath & "compact.cirru"
  echo "Loading module: ", fullpath
  let snapshotInfo = loadSnapshot(fullpath)

  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file

proc runProgram*(snapshotFile: string, initFn: Option[string] = none(string)): CirruData =
  let snapshotInfo = loadSnapshot(snapshotFile)

  for modulePath in snapshotInfo.configs.modules:
    loadModules(modulePath, snapshotFile.parentDir)

  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file
  codeConfigs = snapshotInfo.configs

  # dirty code pin down initFn and reloadFn
  if initFn.isSome():
    codeConfigs.initFn = initFn.get()
  if programReloadFn.isSome():
    codeConfigs.reloadFn = programReloadFn.get()

  programData.clear()

  programCode[coreNs] = FileSource()
  programData[coreNs] = ProgramFile()

  loadCoreDefs(programData, interpret)
  loadCoreSyntax(programData, interpret)

  loadCoreFuncs(programCode)

  # register temp functions
  for procName, tempProc in onLoadPluginProcs:
    programData[coreNs].defs[procName] = CirruData(kind: crDataProc, procVal: tempProc)

  if jsMode or irMode:
    emitCode(codeConfigs.initFn, codeConfigs.reloadFn)
    CirruData(kind: crDataNil)
  else:
    let pieces = codeConfigs.initFn.split('/')

    if pieces.len != 2:
      echo "Unknown initFn", pieces
      raise newException(ValueError, "Unknown initFn")

    runCode(pieces[0], pieces[1], CirruData(kind: crDataNil), true)

proc runEventListener*(event: CirruEdnValue) =
  let ns = codeConfigs.initFn.split('/')[0]
  let def = "on-window-event"

  if programCode.hasKey(ns).not or programCode[ns].defs.hasKey(def).not:
    echo "[Warn]: " & ns & "/" & def & "does not exist"
    return
  try:
    discard runCode(ns, def, event.ednToCirruData(ns, none(CirruDataScope)))

  except ValueError as e:
    coloredEcho fgRed, "Failed to handle event: ", e.msg
    # raise e

proc reloadProgram(snapshotFile: string): void =
  let previousCoreSource = programCode[coreNs]
  let snapshotInfo = loadSnapshot(snapshotFile)
  for fileNs, file in snapshotInfo.files:
    programCode[fileNs] = file
  echo "clearing data under package: ", codeConfigs.pkg
  clearProgramDefs(programData, codeConfigs.pkg)
  genSymIndex = 0 # make it a litter more stable
  programCode[coreNs] = previousCoreSource
  var pieces = codeConfigs.reloadFn.split('/')

  if jsMode or irMode:
    emitCode(codeConfigs.initFn, codeConfigs.reloadFn)
  else:
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
