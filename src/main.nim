
import os
import re
import cirruParser
import cirruParser/types
import cirruParser/helpers
import sequtils
from strutils import join, parseInt
import math
import strformat
import cirruInterpreter/interpreterTypes

proc interpret(expr: CirruNode): CirruValue =
  if expr.kind == cirruString:
    if match(expr.text, re"\d+"):
      return CirruValue(kind: crValueInt, intVal: parseInt(expr.text))
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
          var ret = 0
          for i, v in expr.list[1..^1].map(interpret):
            if v.kind == crValueInt:
              ret += v.intVal
            else:
              raise newException(InterpretError, fmt"Not a number {v.kind}")
          return CirruValue(kind: crValueInt, intVal: ret)
        else:
          raise newException(InterpretError, fmt"Unknown {head.text}")
      else:
        echo "TODO"

proc main(): void =
  case paramCount()
  of 0:
    echo "No file to eval!"
  of 1:
    let sourcePath = paramStr(1)
    let source = readFile sourcePath
    try:
      let program = parseCirru source
      case program.kind
      of cirruString:
        echo "impossible"
      of cirruSeq:
        discard program.list.mapIt(interpret(it))
    except CirruParseError as e:
      echo formatParserFailure(source, e.msg, sourcePath, e.line, e.column)
  else:
    echo "Not sure"

main()
