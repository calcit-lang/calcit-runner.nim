
import os
import strutils
import lists
import json
import strformat
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
import calcit_runner/data
import calcit_runner/core_syntax
import calcit_runner/core_func
import calcit_runner/core_abstract
import calcit_runner/helpers
import calcit_runner/loader
import calcit_runner/scope
import calcit_runner/format
import calcit_runner/gen_data

var programCode: Table[string, FileSource]
var programData: Table[string, ProgramFile]
var runOnce = false

export CirruData, CirruDataKind, `==`, crData

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!")

proc hasNsAndDef(ns: string, def: string): bool =
  if not programCode.hasKey(ns):
    return false
  if not programCode[ns].defs.hasKey(def):
    return false
  return true

# mutual recursion
proc getEvaluatedByPath(ns: string, def: string, scope: CirruDataScope): CirruData
proc loadImportDictByNs(ns: string): Table[string, ImportInfo]
proc preprocess(code: CirruData, localDefs: Hashset[string]): CirruData

proc nativeEval(item: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  var code = interpret(item, scope)
  # code = preprocess(item, toHashset[string](@[]))
  if not checkExprStructure(code):
    raiseEvalError("Expected cirru expr in eval(...)", code)
  dimEcho("eval: ", $code)
  interpret code, scope

proc interpretSymbol(sym: CirruData, scope: CirruDataScope): CirruData =
  if sym.kind != crDataSymbol:
    raiseEvalError("Expects a symbol", sym)

  if sym.scope.isSome:
    let fromOriginalScope = sym.scope.get[sym.symbolVal]
    if fromOriginalScope.isSome:
      return fromOriginalScope.get
  elif scope.contains(sym.symbolVal):
    let fromScope = scope[sym.symbolVal]
    if fromScope.isSome:
      return fromScope.get

  let coreDefs = programData[coreNs].defs
  if coreDefs.contains(sym.symbolVal):
    return coreDefs[sym.symbolVal]

  if hasNsAndDef(coreNs, sym.symbolVal):
    return getEvaluatedByPath(coreNs, sym.symbolVal, scope)

  if hasNsAndDef(sym.ns, sym.symbolVal):
    return getEvaluatedByPath(sym.ns, sym.symbolVal, scope)
  elif sym.ns.startsWith("calcit."):
    raiseEvalError("Cannot find symbol in core lib", sym)
  else:
    let importDict = loadImportDictByNs(sym.ns)
    if sym.symbolVal[0] != '/' and sym.symbolVal.contains("/"):
      let pieces = sym.symbolVal.split('/')
      if pieces.len != 2:
        raiseEvalError("Expects token in ns/def", sym)
      let nsPart = pieces[0]
      let defPart = pieces[1]
      if importDict.hasKey(nsPart):
        let importTarget = importDict[nsPart]
        case importTarget.kind:
        of importNs:
          return getEvaluatedByPath(importTarget.ns, defPart, scope)
        of importDef:
          raiseEvalError(fmt"Unknown ns ${sym.symbolVal}", sym)
    else:
      if importDict.hasKey(sym.symbolVal):
        let importTarget = importDict[sym.symbolVal]
        case importTarget.kind:
        of importDef:
          return getEvaluatedByPath(importTarget.ns, importTarget.def, scope)
        of importNs:
          raiseEvalError(fmt"Unknown def ${sym.symbolVal}", sym)

      raiseEvalError(fmt"Unknown token {sym.symbolVal}", sym)

proc interpret(xs: CirruData, scope: CirruDataScope): CirruData =
  if xs.kind == crDataNil: return xs
  if xs.kind == crDataString: return xs
  if xs.kind == crDataKeyword: return xs
  if xs.kind == crDataNumber: return xs
  if xs.kind == crDataBool: return xs

  if xs.kind == crDataSymbol:
    return interpretSymbol(xs, scope)

  if xs.len == 0:
    raiseEvalError("Cannot interpret empty expression", xs)

  let head = xs[0]

  if head.kind == crDataSymbol and head.symbolVal == "eval":
    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: xs, args: xs[1..^1]))
    if xs.len < 2:
      raiseEvalError("eval expects 1 argument", xs)
    let ret = nativeEval(xs[1], interpret, scope)
    popDefStack()
    return ret

  let value = interpret(head, scope)
  case value.kind
  of crDataString:
    raiseEvalError("String is not a function", xs)

  of crDataFn:
    let f = value.fnVal
    let args = spreadFuncArgs(xs[1..^1], interpret, scope)

    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.fnCode[], args: args))
    var ret = f(args, interpret, scope)
    while ret.isRecur and ret.fnReady:
      ret = f(ret.args, interpret, scope)
    popDefStack()
    return ret

  of crDataMacro:
    let f = value.macroVal
    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.macroCode[], args: xs[1..^1]))

    var quoted = f(spreadArgs(xs[1..^1]), interpret, scope)
    while quoted.isRecur:
      quoted = f(quoted.args.spreadArgs, interpret, scope)
    let ret = interpret(quoted, scope)
    popDefStack()
    return ret

  of crDataSyntax:
    let f = value.syntaxVal

    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.syntaxCode[], args: xs[1..^1]))
    let quoted = f(xs[1..^1], interpret, scope)
    popDefStack()
    return quoted

  else:
    raiseEvalError(fmt"Unknown head {head.symbolVal} for calling", head)

proc preprocessSymbolByPath(ns: string, def: string): CirruData =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  if not programData[ns].defs.hasKey(def):
    var code = programCode[ns].defs[def]
    code = preprocess(code, toHashset[string](@[]))
    programData[ns].defs[def] = interpret(code, CirruDataScope())

  return programData[ns].defs[def]

proc preprocess(code: CirruData, localDefs: Hashset[string]): CirruData =
  case code.kind
  of crDataSymbol:
    if localDefs.contains(code.symbolVal):
      return code
    else:
      var sym = code

      let coreDefs = programData[coreNs].defs
      if coreDefs.contains(sym.symbolVal):
        return coreDefs[sym.symbolVal]

      if hasNsAndDef(coreNs, sym.symbolVal):
        return preprocessSymbolByPath(coreNs, sym.symbolVal)

      if hasNsAndDef(sym.ns, sym.symbolVal):
        return preprocessSymbolByPath(sym.ns, sym.symbolVal)
      elif sym.ns.startsWith("calcit."):
        raiseEvalError("Cannot find symbol in core lib", sym)
      else:
        let importDict = loadImportDictByNs(sym.ns)
        if sym.symbolVal[0] != '/' and sym.symbolVal.contains("/"):
          let pieces = sym.symbolVal.split('/')
          if pieces.len != 2:
            raiseEvalError("Expects token in ns/def", sym)
          let nsPart = pieces[0]
          let defPart = pieces[1]
          if importDict.hasKey(nsPart):
            let importTarget = importDict[nsPart]
            case importTarget.kind:
            of importNs:
              return preprocessSymbolByPath(importTarget.ns, defPart)
            of importDef:
              raiseEvalError(fmt"Unknown ns ${sym.symbolVal}", sym)
        else:
          if importDict.hasKey(sym.symbolVal):
            let importTarget = importDict[sym.symbolVal]
            case importTarget.kind:
            of importDef:
              return preprocessSymbolByPath(importTarget.ns, importTarget.def)
            of importNs:
              raiseEvalError(fmt"Unknown def ${sym.symbolVal}", sym)

          raiseEvalError(fmt"Unknown token {sym.symbolVal}", sym)

  of crDataList:
    if code.listVal.len == 0:
      return code
    else:
      let head = code.listVal[0]
      let value = preprocess(head, localDefs)
      case value.kind
      of crDataFn:
        var xs = initTernaryTreeList[CirruData](@[value])
        for child in code.listVal.rest:
          xs = xs.append preprocess(child, localDefs)
        return CirruData(kind: crDataList, listVal: xs)
      of crDataMacro:
        let f = value.macroVal
        let emptyScope = CirruDataScope()
        pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.macroCode[], args: code[1..^1]))

        var quoted = f(spreadArgs(code[1..^1]), interpret, emptyScope)
        while quoted.isRecur:
          quoted = f(quoted.args.spreadArgs, interpret, emptyScope)
        popDefStack()
        echo "Expanded macro", quoted
        return preprocess(quoted, localDefs)
      of crDataSyntax:
        echo "Should preprocess syntax", code
        return code
      else:
        return code
  else:
    return code

proc getEvaluatedByPath(ns: string, def: string, scope: CirruDataScope): CirruData =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  if not programData[ns].defs.hasKey(def):
    let code = programCode[ns].defs[def]
    programData[ns].defs[def] = interpret(code, scope)

  return programData[ns].defs[def]

proc loadImportDictByNs(ns: string): Table[string, ImportInfo] =
  let dict = programData[ns].ns
  if dict.isSome:
    return dict.get
  else:
    let v = extractNsInfo(programCode[ns].ns)
    programData[ns].ns = some(v)
    return v

proc showStack(): void =
  let errorStack = reversed(defStack)
  for item in errorStack:
    echo item.ns, "/", item.def
    dimEcho $item.code
    dimEcho "args: ", $CirruData(kind: crDataList, listVal: initTernaryTreeList(item.args))

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

  let scope = CirruDataScope()

  let pieces = if initFn.isSome:
    initFn.get.split("/")
  else:
   codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  discard preprocessSymbolByPath(pieces[0], pieces[1])
  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crDataFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let mainCode = programCode[pieces[0]].defs[pieces[1]]
  defStack = initDoublyLinkedList[StackInfo]()
  pushDefStack StackInfo(ns: pieces[0], def: pieces[1], code: mainCode)

  let f = entry.fnVal
  let args: seq[CirruData] = @[]
  try:
    return f(args, interpret, scope)

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

  discard preprocessSymbolByPath(pieces[0], pieces[1])
  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crDataFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let mainCode = programCode[pieces[0]].defs[pieces[1]]
  defStack = initDoublyLinkedList[StackInfo]()
  pushDefStack StackInfo(ns: pieces[0], def: pieces[1], code: mainCode)

  let f = entry.fnVal
  let args: seq[CirruData] = @[]

  try:
    discard f(args, interpret, scope)

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
