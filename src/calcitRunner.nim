
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

proc interpret(expr: CirruNode, ns: string, scope: CirruDataScope): CirruData =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+(\.\d+)?"):
      return CirruData(kind: crDataNumber, numberVal: parseFloat(expr.text))
    elif expr.text == "true":
      return CirruData(kind: crDataBool, boolVal: true)
    elif expr.text == "false":
      return CirruData(kind: crDataBool, boolVal: false)
    elif (expr.text.len > 0) and (expr.text[0] == '|' or expr.text[0] == '"'):
      return CirruData(kind: crDataString, stringVal: expr.text[1..^1])
    else:
      let fromScope = scope.get(expr.text)
      if fromScope.isSome:
        return fromScope.get
      elif hasNsAndDef(ns, expr.text):
        return getEvaluatedByPath(ns, expr.text, scope)
      else:
        let importDict = loadImportDictByNs(ns)
        if expr.text.contains("/"):
          let pieces = expr.text.split('/')
          if pieces.len != 2:
            raiseInterpretExceptionAtNode("Expects token in ns/def", expr)
          let nsPart = pieces[0]
          let defPart = pieces[1]
          if importDict.hasKey(nsPart):
            let importTarget = importDict[nsPart]
            case importTarget.kind:
            of importNs:
              return getEvaluatedByPath(importTarget.ns, defPart, scope)
            of importDef:
              raiseInterpretExceptionAtNode(fmt"Unknown ns ${expr.text}", expr)
        else:
          if importDict.hasKey(expr.text):
            let importTarget = importDict[expr.text]
            case importTarget.kind:
            of importDef:
              return getEvaluatedByPath(importTarget.ns, importTarget.def, scope)
            of importNs:
              raiseInterpretExceptionAtNode(fmt"Unknown def ${expr.text}", expr)

          raiseInterpretExceptionAtNode(fmt"Unknown token {expr.text}", expr)
  else:
    if expr.len == 0:
      return
    else:
      let head = expr[0]
      case head.kind
      of cirruString:
        case head.text
        of "println", "echo":
          echo expr[1..^1].map(proc(x: CirruNode): CirruData =
            interpret(x, ns, scope)
          ).map(`$`).join(" ")
        of "pr-str":
          echo expr[1..^1].map(proc(x: CirruNode): CirruData =
            interpret(x, ns, scope)
          ).map(proc (x: CirruData): string =
            if x.kind == crDataString:
              return escape(x.stringVal)
            else:
              return $x
          ).join(" ")
        of "+":
          return evalAdd(expr, interpret, ns, scope)
        of "-":
          return evalMinus(expr, interpret, ns, scope)
        of "if":
          return evalIf(expr, interpret, ns, scope)
        of "[]":
          return evalArray(expr, interpret, ns, scope)
        of "{}":
          return evalTable(expr, interpret, ns, scope)
        of "read-file":
          return evalReadFile(expr, interpret, ns, scope)
        of "write-file":
          return evalWriteFile(expr, interpret, ns, scope)
        of ";":
          return evalComment()
        of "load-json":
          return evalLoadJson(expr, interpret, ns, scope)
        of "type-of":
          return evalType(expr, interpret, ns, scope)
        of "defn":
          return evalDefn(expr, interpret, ns, scope)
        of "let":
          return evalLet(expr, interpret, ns, scope)
        of "do":
          return evalDo(expr, interpret, ns, scope)
        of ">", "<", "=", "!=":
          return evalCompare(expr, interpret, ns, scope)
        else:
          let value = interpret(head, ns, scope)
          case value.kind
          of crDataString:
            var value = value.stringVal
            return callStringMethod(value, expr, interpret, ns, scope)
          of crDataFn:
            let f = value.fnVal
            var args: seq[CirruData] = @[]
            let argsCode = expr[1..^1]
            for x in argsCode:
              args.add interpret(x, ns, scope)
            return f(args, interpret, ns, scope)

          else:
            raiseInterpretExceptionAtNode(fmt"Unknown head {head.text} for calling", head)
      else:
        let headValue = interpret(expr[0], ns, scope)
        case headValue.kind:
        of crDataFn:
          echo "NOT implemented fn"
          quit 1
        of crDataVector:
          var value = headValue.vectorVal
          return callArrayMethod(value, expr, interpret, ns, scope)
        of crDataMap:
          var value = headValue.mapVal
          return callTableMethod(value, expr, interpret, ns, scope)
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

    file.defs[def] = interpret(code, ns, scope)

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
    return f(args, interpret, pieces[0], scope)

  except CirruInterpretError as e:
    coloredEcho fgRed, "\nError: failed to interpret"
    echo e.msg
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
  discard f(args, interpret, pieces[0], scope)

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
