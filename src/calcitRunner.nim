
import os
import re
import sequtils
import strutils
import json
import strformat
import terminal
import tables
import options
import parseopt

import cirruParser
import cirruEdn
import libfswatch
import libfswatch/fswatch

import calcitRunner/types
import calcitRunner/data
import calcitRunner/operations
import calcitRunner/helpers
import calcitRunner/loader
import calcitRunner/scope
import calcitRunner/format
import calcitRunner/genData

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

proc interpret(expr: CirruData, scope: CirruDataScope): CirruData =
  if expr.kind == crDataSymbol:
    if match(expr.symbolVal, re"\d+(\.\d+)?"):
      return CirruData(kind: crDataNumber, numberVal: parseFloat(expr.symbolVal))
    elif expr.symbolVal == "true":
      return CirruData(kind: crDataBool, boolVal: true)
    elif expr.symbolVal == "false":
      return CirruData(kind: crDataBool, boolVal: false)
    elif (expr.symbolVal.len > 0) and (expr.symbolVal[0] == '|' or expr.symbolVal[0] == '"'):
      return CirruData(kind: crDataString, stringVal: expr.symbolVal[1..^1])
    else:
      let fromScope = scope.get(expr.symbolVal)
      if fromScope.isSome:
        return fromScope.get
      elif hasNsAndDef(expr.ns, expr.symbolVal):
        return getEvaluatedByPath(expr.ns, expr.symbolVal, scope)
      else:
        let importDict = loadImportDictByNs(expr.ns)
        if expr.symbolVal.contains("/"):
          let pieces = expr.symbolVal.split('/')
          if pieces.len != 2:
            raiseEvalError("Expects token in ns/def", expr)
          let nsPart = pieces[0]
          let defPart = pieces[1]
          if importDict.hasKey(nsPart):
            let importTarget = importDict[nsPart]
            case importTarget.kind:
            of importNs:
              return getEvaluatedByPath(importTarget.ns, defPart, scope)
            of importDef:
              raiseEvalError(fmt"Unknown ns ${expr.symbolVal}", expr)
        else:
          if importDict.hasKey(expr.symbolVal):
            let importTarget = importDict[expr.symbolVal]
            case importTarget.kind:
            of importDef:
              return getEvaluatedByPath(importTarget.ns, importTarget.def, scope)
            of importNs:
              raiseEvalError(fmt"Unknown def ${expr.symbolVal}", expr)

          raiseEvalError(fmt"Unknown token {expr.symbolVal}", expr)
  else:
    if expr.len == 0:
      return
    else:
      let head = expr[0]
      case head.kind
      of crDataSymbol:
        case head.symbolVal
        of "println", "echo":
          echo expr[1..^1].map(proc(x: CirruData): CirruData =
            interpret(x, scope)
          ).map(`$`).join(" ")
        of "pr-str":
          echo expr[1..^1].map(proc(x: CirruData): CirruData =
            interpret(x, scope)
          ).map(proc (x: CirruData): string =
            if x.kind == crDataSymbol:
              return escape(x.symbolVal)
            else:
              return $x
          ).join(" ")
        of "+":
          return evalAdd(expr, interpret, scope)
        of "-":
          return evalMinus(expr, interpret, scope)
        of "if":
          return evalIf(expr, interpret, scope)
        of "[]":
          return evalArray(expr, interpret, scope)
        of "{}":
          return evalTable(expr, interpret, scope)
        of "read-file":
          return evalReadFile(expr, interpret, scope)
        of "write-file":
          return evalWriteFile(expr, interpret, scope)
        of ";":
          return evalComment()
        of "load-json":
          return evalLoadJson(expr, interpret, scope)
        of "type-of":
          return evalType(expr, interpret, scope)
        of "defn":
          return evalDefn(expr, interpret, scope)
        of "let":
          return evalLet(expr, interpret, scope)
        of "do":
          return evalDo(expr, interpret, scope)
        of ">", "<", "=", "!=":
          return evalCompare(expr, interpret, scope)
        else:
          let value = interpret(head, scope)
          case value.kind
          of crDataString:
            var value = value.symbolVal
            return callStringMethod(value, expr, interpret, scope)
          of crDataFn:
            let f = value.fnVal
            var args: seq[CirruData] = @[]
            let argsCode = expr[1..^1]
            for x in argsCode:
              args.add interpret(x, scope)
            return f(args, interpret, scope)

          else:
            raiseEvalError(fmt"Unknown head {head.symbolVal} for calling", head)
      else:
        let headValue = interpret(expr[0], scope)
        case headValue.kind:
        of crDataFn:
          echo "NOT implemented fn"
          quit 1
        of crDataVector:
          var value = headValue.vectorVal
          return callArrayMethod(value, expr, interpret, scope)
        of crDataMap:
          var value = headValue.mapVal
          return callTableMethod(value, expr, interpret, scope)
        else:
          echo "TODO"
          quit 1

proc getEvaluatedByPath(ns: string, def: string, scope: CirruDataScope): CirruData =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  var file = programData[ns]

  if not file.defs.hasKey(def):
    let code = programCode[ns].defs[def]

    file.defs[def] = interpret(code, scope)

  return file.defs[def]

proc loadImportDictByNs(ns: string): Table[string, ImportInfo] =
  let dict = programData[ns].ns
  if dict.isSome:
    return dict.get
  else:
    let v = extractNsInfo(programCode[ns].ns)
    programData[ns].ns = some(v)
    return v

proc runProgram*(snapshotFile: string): CirruData =
  programCode = loadSnapshot(snapshotFile)
  codeConfigs = loadCodeConfigs(snapshotFile)
  var scope = CirruDataScope(parent: none(CirruDataScope))

  let pieces = codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crDataFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruData] = @[]
  try:
    return f(args, interpret, scope)

  except CirruEvalError as e:
    coloredEcho fgRed, "\nError: failed to interpret"
    echo e.msg
    echo e.code
    raise e

proc reloadProgram(snapshotFile: string): void =
  programCode = loadSnapshot(snapshotFile)
  programData.clear()
  var scope = CirruDataScope(parent: none(CirruDataScope))

  let pieces = codeConfigs.reloadFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crDataFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruData] = @[]
  discard f(args, interpret, scope)

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

    except CirruInterpretError as e:
      coloredEcho fgRed, "\nError: failed to interpret"
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
