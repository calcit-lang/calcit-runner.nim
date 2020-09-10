
import os
import re
import sequtils
from strutils import join, parseFloat, parseInt, split
import json
import strformat
import terminal
import tables

import cirruParser
import cirruEdn
import libfswatch
import libfswatch/fswatch

import cirruInterpreter/types
import cirruInterpreter/operations
import cirruInterpreter/helpers
import cirruInterpreter/loader

proc interpret(expr: CirruNode): CirruEdnValue =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+"):
      return CirruEdnValue(kind: crEdnNumber, numberVal: parseFloat(expr.text))
    elif expr.text == "true":
      return CirruEdnValue(kind: crEdnBool, boolVal: true)
    elif expr.text == "false":
      return CirruEdnValue(kind: crEdnBool, boolVal: false)
    elif (expr.text.len > 0) and (expr.text[0] == '|' or expr.text[0] == '"'):
      return CirruEdnValue(kind: crEdnString, stringVal: expr.text[1..^1])
    else:
      return CirruEdnValue(kind: crEdnString, stringVal: expr.text)
  else:
    if expr.list.len == 0:
      return
    else:
      let head = expr.list[0]
      case head.kind
      of cirruString:
        case head.text
        of "println", "echo":
          echo expr.list[1..^1].map(interpret).map(`$`).join(" ")
        of "+":
          return evalAdd(expr.list, interpret)
        of "-":
          return evalMinus(expr.list, interpret)
        of "if":
          return evalIf(expr.list, interpret)
        of "[]":
          return evalArray(expr.list, interpret)
        of "{}":
          return evalTable(expr.list, interpret)
        of "read-file":
          return evalReadFile(expr.list, interpret)
        of "write-file":
          return evalWriteFile(expr.list, interpret)
        of ";":
          return evalComment()
        of "load-json":
          return evalLoadJson(expr.list, interpret)
        of "type-of":
          return evalType(expr.list, interpret)
        of "defn":
          return evalDefn(expr.list, interpret)
        else:
          let value = interpret(head)
          case value.kind
          of crEdnString:
            var value = value.stringVal
            return callStringMethod(value, expr.list, interpret)
          else:
            raiseInterpretExceptionAtNode(fmt"Unknown head {head.text}", head)
      else:
        let headValue = interpret(expr.list[0])
        case headValue.kind:
        of crEdnFn:
          echo "NOT implemented fn"
          quit 1
        of crEdnVector:
          var value = headValue.vectorVal
          return callArrayMethod(value, expr.list, interpret)
        of crEdnMap:
          var value = headValue.mapVal
          return callTableMethod(value, expr.list, interpret)
        else:
          echo "TODO"
          quit 1

proc evalFile(sourcePath: string): void =
  var source: string
  try:
    source = readFile sourcePath
    let program = parseCirru source
    case program.kind
    of cirruString:
      raise newException(CirruCommandError, "Call eval with code")
    of cirruSeq:
      # discard program.list.mapIt(interpret(it))
      echo "doing nothing"

  except CirruParseError as e:
    coloredEcho fgRed, "\nError: failed to parse"
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruInterpretError as e:
    coloredEcho fgRed, "\nError: failed to interpret"
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruCommandError as e:
    coloredEcho fgRed, "Failed to run command"
    raise e

var programCode: Table[string, FileSource]
var programData: Table[string, Table[string, MaybeNil[CirruEdnValue]]]

var codeConfigs = CodeConfigs(initFn: "app.main/main!", reloadFn: "app.main/reload!")

proc getEvaluatedByPath(ns: string, def: string): CirruEdnValue =
  if not programData.hasKey(ns):
    var newFile: Table[string, MaybeNil[CirruEdnValue]]
    programData[ns] = newFile

  var file = programData[ns]

  if not file.hasKey(def):
    let code = programCode[ns].defs[def]

    file[def] = MaybeNil[CirruEdnValue](kind: beSomething, value: interpret(code))

  return file[def].value

proc runProgram(): void =
  programCode = loadSnapshot()
  codeConfigs = loadCodeConfigs()

  let pieces = codeConfigs.initFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1])

  if entry.kind != crEdnFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruEdnValue] = @[]
  discard f(args, interpret)

proc reloadProgram(): void =
  programCode = loadSnapshot()

  let pieces = codeConfigs.reloadFn.split('/')

  if pieces.len != 2:
    echo "Unknown initFn", pieces
    raise newException(ValueError, "Unknown initFn")

  let entry = getEvaluatedByPath(pieces[0], pieces[1])

  if entry.kind != crEdnFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruEdnValue] = @[]
  discard f(args, interpret)


proc fileChangeCb(event: fsw_cevent, event_num: cuint): void =
  coloredEcho fgYellow, "\n-------- file change --------\n"
  loadChanges(programCode)
  try:
    reloadProgram()
  except ValueError as e:
    echo "Failed to rerun program: "

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
