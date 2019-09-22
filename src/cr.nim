
import os
import re
import cirruParser
import sequtils
from strutils import join, parseInt
import math
import strformat
import cirruInterpreter/types
import cirruInterpreter/operations
import osproc
import streams

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
        of "println":
          echo expr.list[1..^1].map(interpret).map(toString).join(" ")
        of "+":
          return evalAdd(expr.list, interpret)
        of "-":
          return evalMinus(expr.list, interpret)
        of "if":
          return evalIf(expr.list, interpret)
        of "read-file":
          return evalReadFile(expr.list, interpret)
        else:
          raise newException(InterpretError, fmt"Unknown {head.text}")
      else:
        echo "TODO"

proc evalFile(sourcePath: string): void =
  var source: string
  try:
    source = readFile sourcePath
    let program = parseCirru source
    case program.kind
    of cirruString:
      raise newException(InterpretError, "Call eval with code")
    of cirruSeq:
      discard program.list.mapIt(interpret(it))

  except CirruParseError as e:
    echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)
  except InterpretError as e:
    echo "Failed to interpret"
    raise e


proc watchFile(sourcePath: string): void =
  let child = startProcess("/usr/local/bin/fswatch", "", [sourcePath])
  let sub = outputStream(child)
  while true:
    let line = readLine(sub)

    # TODO, tell which file to reload
    evalFile(sourcePath)

proc main(): void =
  case paramCount()
  of 0:
    echo "No file to eval!"
  of 1:
    let sourcePath = paramStr(1)
    evalFile(sourcePath)
    watchFile(sourcePath)

  else:
    echo "Not sure"

main()
