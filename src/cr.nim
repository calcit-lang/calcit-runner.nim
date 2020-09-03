
import os
import re
import sequtils
from strutils import join, parseFloat, parseInt
import json
import strformat
import osproc
import streams
import terminal
import tables

import cirruParser
import cirruEdn

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
    setForegroundColor(fgRed)
    echo "\nError: failed to parse"
    resetAttributes()
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruInterpretError as e:
    setForegroundColor(fgRed)
    echo "\nError: failed to interpret"
    resetAttributes()
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)

  except CirruCommandError as e:
    setForegroundColor(fgRed)
    echo "Failed to run command"
    raise e

var programCode: Table[string, FileSource]
var programData: Table[string, Table[string, MaybeNil[CirruEdnValue]]]

proc getEvaluatedByPath(ns: string, def: string): CirruEdnValue =
  if not programData.hasKey(ns):
    var newFile: Table[string, MaybeNil[CirruEdnValue]]
    programData[ns] = newFile

  var file = programData[ns]

  if not file.hasKey(def):
    let code = programCode[ns].defs[def]

    file[def] = MaybeNil[CirruEdnValue](kind: beSomething, value: interpret(code))

  return file[def].value

proc watchFile(): void =
  if not existsFile(incrementFile):
    writeFile incrementFile, "{}"
  let child = startProcess("/usr/local/bin/fswatch", "", [incrementFile])
  let sub = outputStream(child)
  while true:
    let line = readLine(sub)

    setForegroundColor(fgCyan)
    echo "\n-------- file change --------\n"
    resetAttributes()

    echo %*loadChanges()

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc main(): void =
  programCode = loadSnapshot()


  let entry = getEvaluatedByPath("app.main", "main!")

  if entry.kind != crEdnFn:
    raise newException(ValueError, "expects a function at app.main/main!")

  let f = entry.fnVal
  let args: seq[CirruEdnValue] = @[]
  echo f(args, interpret)

  setControlCHook(handleControl)
  watchFile()

main()
