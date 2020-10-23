
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
import calcit_runner/errors
import calcit_runner/loader
import calcit_runner/stack
import calcit_runner/gen_data
import calcit_runner/preprocess
import calcit_runner/gen_code

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
  code = preprocess(item, toHashset[string](@[]))
  if not checkExprStructure(code):
    raiseEvalError("Expected cirru expr in eval(...)", code)
  dimEcho("eval: ", $code)
  interpret code, scope

proc interpretSymbol(sym: CirruData, scope: CirruDataScope): CirruData =
  if sym.kind != crDataSymbol:
    raiseEvalError("Expects a symbol", sym)

  if sym.resolved.isSome:
    let path = sym.resolved.get

    return programData[path.ns].defs[path.def]

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
  let loadedSym = preprocess(sym, toHashset[string](@[]))

  echo "[Warn] load unprocessed variable: ", sym
  if loadedSym.resolved.isSome:
    let path = loadedSym.resolved.get
    return programData[path.ns].defs[path.def]

  raiseEvalError(fmt"Symbol not initialized or recognized: {sym.symbolVal}", sym)

proc interpret(xs: CirruData, scope: CirruDataScope): CirruData =
  if xs.kind == crDataNil: return xs
  if xs.kind == crDataString: return xs
  if xs.kind == crDataKeyword: return xs
  if xs.kind == crDataNumber: return xs
  if xs.kind == crDataBool: return xs
  if xs.kind == crDataFn: return xs

  if xs.kind == crDataSymbol:
    return interpretSymbol(xs, scope)

  if xs.len == 0:
    raiseEvalError("Cannot interpret empty expression", xs)

  # echo "interpret: ", xs

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

    # echo "HEAD: ", head, " ", xs
    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.fnCode[], args: args))
    # echo "calling: ", CirruData(kind: crDataList, listVal: initTernaryTreeList(args)), " ", xs
    var ret = f(args, interpret, scope)
    while ret.isRecur and ret.fnReady:
      ret = f(ret.args, interpret, scope)
    popDefStack()
    return ret

  of crDataMacro:
    echo "[warn] Found macros: ", xs
    raiseEvalError("Macros are supposed to be handled during preprocessing", xs)

  of crDataSyntax:
    let f = value.syntaxVal

    pushDefStack(StackInfo(ns: head.ns, def: head.symbolVal, code: value.syntaxCode[], args: xs[1..^1]))
    let quoted = f(xs[1..^1], interpret, scope)
    popDefStack()
    return quoted

  else:
    raiseEvalError(fmt"Unknown head {head.symbolVal} for calling", head)

proc placeholderFunc(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  echo "[Warn] placeholder function for preprocessing"
  return CirruData(kind: crDataNil)

proc preprocessSymbolByPath(ns: string, def: string): void =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  if not programData[ns].defs.hasKey(def):
    var code = programCode[ns].defs[def]
    programData[ns].defs[def] = CirruData(kind: crDataFn, fnVal: placeholderFunc, fnCode: fakeNativeCode("placeholder"))
    code = preprocess(code, toHashset[string](@[]))
    # echo "setting: ", ns, "/", def
    # echo "processed code: ", code
    programData[ns].defs[def] = interpret(code, CirruDataScope())

proc preprocessHelper(code: CirruData, localDefs: Hashset[string]): CirruData =
  preprocess(code, localDefs)

proc preprocess(code: CirruData, localDefs: Hashset[string]): CirruData =
  # echo "preprocess: ", code
  case code.kind
  of crDataSymbol:
    if localDefs.contains(code.symbolVal):
      return code
    elif code.symbolVal == "&" or code.symbolVal == "~":
      return code
    else:
      var sym = code

      let coreDefs = programData[coreNs].defs
      if coreDefs.contains(sym.symbolVal):
        sym.resolved = some((coreNs, sym.symbolVal))
        return sym

      if hasNsAndDef(coreNs, sym.symbolVal):
        preprocessSymbolByPath(coreNs, sym.symbolVal)
        sym.resolved = some((coreNs, sym.symbolVal))
        return sym

      if hasNsAndDef(sym.ns, sym.symbolVal):
        preprocessSymbolByPath(sym.ns, sym.symbolVal)
        sym.resolved = some((sym.ns, sym.symbolVal))
        return sym
      elif sym.ns.startsWith("calcit."):
        raiseEvalError(fmt"Cannot find symbol in core lib: ${sym}", sym)
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
              preprocessSymbolByPath(importTarget.ns, defPart)
              sym.resolved = some((importTarget.ns, defPart))
              return sym
            of importDef:
              raiseEvalError(fmt"Unknown ns ${sym.symbolVal}", sym)
        else:
          if importDict.hasKey(sym.symbolVal):
            let importTarget = importDict[sym.symbolVal]
            case importTarget.kind:
            of importDef:
              preprocessSymbolByPath(importTarget.ns, importTarget.def)
              sym.resolved = some((importTarget.ns, importTarget.def))
              return sym
            of importNs:
              raiseEvalError(fmt"Unknown def ${sym.symbolVal}", sym)

          # raiseEvalError(fmt"Unknown token {sym.symbolVal}", sym)
          return sym

  of crDataList:
    if code.listVal.len == 0:
      return code
    else:
      let head = code.listVal[0]
      let originalValue = preprocess(head, localDefs)
      var value = originalValue

      if value.kind == crDataSymbol and value.resolved.isSome:
        let path = value.resolved.get
        value = programData[path.ns].defs[path.def]

      case value.kind
      of crDataFn:
        var xs = initTernaryTreeList[CirruData](@[originalValue])
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
        # echo "Expanded macro: ", code, "  ->  ", quoted
        return preprocess(quoted, localDefs)
      of crDataSyntax:
        if head.kind != crDataSymbol:
          raiseEvalError("Expected syntax head", code)
        case head.symbolVal
        of ";":
          return code
        of "defn", "defmacro":
          return processDefn(code, localDefs, preprocessHelper)
        of "fn":
          return processFn(code, localDefs, preprocessHelper)
        of "let", "loop":
          return processBinding(code, localDefs, preprocessHelper)
        of "[]", "if", "assert", "do", "quote-replace":
          return processAll(code, localDefs, preprocessHelper)
        of "{}":
          return processMap(code, localDefs, preprocessHelper)
        of "quote":
          return processQuote(code, localDefs, preprocessHelper)
        else:
          raiseEvalError(fmt"Unknown syntax: ${head}", code)

        return code
      else:
        return code
  else:
    return code

proc getEvaluatedByPath(ns: string, def: string, scope: CirruDataScope): CirruData =
  if not programData.hasKey(ns):
    raiseEvalError(fmt"Not initialized during preprocessing: {ns}/{def}", CirruData(kind: crDataNil))

  if not programData[ns].defs.hasKey(def):
    var code = programCode[ns].defs[def]
    code = preprocess(code, toHashset[string](@[]))
    raiseEvalError(fmt"Not initialized during preprocessing: {ns}/{def}", CirruData(kind: crDataNil))
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

  try:
    preprocessSymbolByPath(pieces[0], pieces[1])
    let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

    if entry.kind != crDataFn:
      raise newException(ValueError, "expects a function at app.main/main!")

    let mainCode = programCode[pieces[0]].defs[pieces[1]]
    defStack = initDoublyLinkedList[StackInfo]()
    pushDefStack StackInfo(ns: pieces[0], def: pieces[1], code: mainCode)

    let f = entry.fnVal
    let args: seq[CirruData] = @[]

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

proc clearProgramDefs*(programData: var Table[string, ProgramFile]): void =
  for ns, f in programData:
    var file = programData[ns]
    if not ns.startsWith("calcit."):
      file.ns = none(Table[string, ImportInfo])
      file.defs.clear

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

    let f = entry.fnVal
    let args: seq[CirruData] = @[]

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
