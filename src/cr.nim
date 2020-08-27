
import os
import re
import sequtils
from strutils import join, parseInt
import strformat
import osproc
import streams
import terminal

import cirruParser
import cirruEdn

import cirruInterpreter/types
import cirruInterpreter/operations
import cirruInterpreter/helpers
import cirruInterpreter/loader


proc interpret(expr: CirruNode): CirruValue =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+"):
      return CirruValue(kind: crValueInt, intVal: parseInt(expr.text))
    elif expr.text == "true":
      return CirruValue(kind: crValueBool, boolVal: true)
    elif expr.text == "false":
      return CirruValue(kind: crValueBool, boolVal: false)
    elif (expr.text.len > 0) and (expr.text[0] == '|' or expr.text[0] == '"'):
      return CirruValue(kind: crValueString, stringVal: expr.text[1..^1])
    else:
      return CirruValue(kind: crValueString, stringVal: expr.text)
  else:
    if expr.list.len == 0:
      return
    else:
      let head = expr.list[0]
      case head.kind
      of cirruString:
        case head.text
        of "println", "echo":
          echo expr.list[1..^1].map(interpret).map(toString).join(" ")
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
        else:
          let value = interpret(head)
          case value.kind
          of crValueString:
            var value = value.stringVal
            return callStringMethod(value, expr.list, interpret)
          else:
            raiseInterpretExceptionAtNode(fmt"Unknown head {head.text}", head)
      else:
        let headValue = interpret(expr.list[0])
        case headValue.kind:
        of crValueFn:
          echo "NOT implemented fn"
          quit 1
        of crValueArray:
          var value = headValue.arrayVal
          return callArrayMethod(value, expr.list, interpret)
        of crValueTable:
          var value = headValue.tableVal
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


var snapshot: int = 0


proc evalSnapshot(): void =
  echo "evaling", snapshot

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

    loadChanges()

# https://rosettacode.org/wiki/Handle_a_signal#Nim
proc handleControl() {.noconv.} =
  echo "\nKilled with Control c."
  quit 0

proc main(): void =
  loadSnapshot()
  evalSnapshot()

  setControlCHook(handleControl)
  watchFile()

main()
