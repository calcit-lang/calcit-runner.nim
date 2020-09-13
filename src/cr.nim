
import os
import re
import sequtils
from strutils import join, parseFloat, parseInt, split
import json
import strformat
import terminal
import tables
import options

import cirruParser
import cirruEdn
import libfswatch
import libfswatch/fswatch

import calcitRunner/types
import calcitRunner/operations
import calcitRunner/helpers
import calcitRunner/loader
import calcitRunner/scope

var programCode: Table[string, FileSource]
var programData: Table[string, ProgramFile]

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!")

proc interpret(expr: CirruNode, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+(\.\d+)?"):
      return CirruEdnValue(kind: crEdnNumber, numberVal: parseFloat(expr.text))
    elif expr.text == "true":
      return CirruEdnValue(kind: crEdnBool, boolVal: true)
    elif expr.text == "false":
      return CirruEdnValue(kind: crEdnBool, boolVal: false)
    elif (expr.text.len > 0) and (expr.text[0] == '|' or expr.text[0] == '"'):
      return CirruEdnValue(kind: crEdnString, stringVal: expr.text[1..^1])
    else:
      let fromScope = scope.get(expr.text)
      if fromScope.isSome:
        return fromScope.get
      else:
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
          echo expr[1..^1].map(proc(x: CirruNode): CirruEdnValue =
            interpret(x, ns, scope)
          ).map(`$`).join(" ")
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
        else:
          let value = interpret(head, ns, scope)
          case value.kind
          of crEdnString:
            var value = value.stringVal
            return callStringMethod(value, expr, interpret, ns, scope)
          else:
            raiseInterpretExceptionAtNode(fmt"Unknown head {head.text}", head)
      else:
        let headValue = interpret(expr[0], ns, scope)
        case headValue.kind:
        of crEdnFn:
          echo "NOT implemented fn"
          quit 1
        of crEdnVector:
          var value = headValue.vectorVal
          return callArrayMethod(value, expr, interpret, ns, scope)
        of crEdnMap:
          var value = headValue.mapVal
          return callTableMethod(value, expr, interpret, ns, scope)
        else:
          echo "TODO"
          quit 1

proc getEvaluatedByPath(ns: string, def: string, scope: CirruEdnScope): CirruEdnValue =
  if not programData.hasKey(ns):
    var newFile = ProgramFile()
    programData[ns] = newFile

  var file = programData[ns]

  if not file.defs.hasKey(def):
    let code = programCode[ns].defs[def]

    file.defs[def] = interpret(code, ns, scope)

  return file.defs[def]

proc runProgram(): void =
  programCode = loadSnapshot()
  codeConfigs = loadCodeConfigs()
  var scope = CirruEdnScope(parent: none(CirruEdnScope))

  let pieces = codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crEdnFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruEdnValue] = @[]
  discard f(args, interpret, pieces[0], scope)

proc reloadProgram(): void =
  programCode = loadSnapshot()
  programData.clear()
  var scope = CirruEdnScope(parent: none(CirruEdnScope))

  let pieces = codeConfigs.reloadFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1], scope)

  if entry.kind != crEdnFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruEdnValue] = @[]
  discard f(args, interpret, pieces[0], scope)


proc fileChangeCb(event: fsw_cevent, event_num: cuint): void =
  coloredEcho fgYellow, "\n-------- file change --------\n"
  loadChanges(programCode)
  try:
    reloadProgram()
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

proc watchFile(): void =
  if not existsFile(incrementFile):
    writeFile incrementFile, "{}"

  var mon = newMonitor()
  mon.addPath(incrementFile)
  mon.setCallback(fileChangeCb)
  mon.start()

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc main(): void =
  runProgram()
  setControlCHook(handleControl)
  watchFile()

main()
