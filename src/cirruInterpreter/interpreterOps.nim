
import os
import re
import cirruParser
import cirruParser/types
import cirruParser/helpers
import sequtils
from strutils import join, parseInt
import math
import strformat
import ./interpreterTypes

proc evalAdd*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  var ret = 0
  for v in exprList[1..^1].map(interpret):
    if v.kind == crValueInt:
      ret += v.intVal
    else:
      raise newException(InterpretError, fmt"Not a number {v.kind}")
  return CirruValue(kind: crValueInt, intVal: ret)

proc evalMinus*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if (exprList.len == 1):
    return CirruValue(kind: crValueInt, intVal: 0)
  elif (exprList.len == 2):
    let ret = interpret(exprList[1])
    if ret.kind == crValueInt:
      return ret
    else:
      raise newException(InterpretError, fmt"Not a number {ret.kind}")
  else:
    let x0 = interpret(exprList[1])
    var ret = 0
    if x0.kind == crValueInt:
      ret = x0.intVal
    else:
      raise newException(InterpretError, fmt"Not a number {x0.kind}")
    for v in exprList[2..^1].map(interpret):
      if v.kind == crValueInt:
        ret -= v.intVal
      else:
        raise newException(InterpretError, fmt"Not a number {v.kind}")
    return CirruValue(kind: crValueInt, intVal: ret)

proc evalIf*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if (exprList.len == 1):
    raise newException(InterpretError, "No arguments for if")
  elif (exprList.len == 2):
    raise newException(InterpretError, "No arguments for if")
  elif (exprList.len == 3):
    let cond = interpret(exprList[1])
    if cond.kind == crValueBool:
      if cond.boolVal:
        return interpret(exprList[2])
      else:
        return CirruValue(kind: crValueNil)
    else:
      raise newException(InterpretError, "Not a bool in if")
  elif (exprList.len == 4):
    let cond = interpret(exprList[1])
    if cond.kind == crValueBool:
      if cond.boolVal:
        return interpret(exprList[2])
      else:
        return interpret(exprList[3])
    else:
      raise newException(InterpretError, "Not a bool in if")
  else:
    raise newException(InterpretError, "Too many arguments for if")

proc evalReadFile*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if exprList.len == 1:
    raise newException(InterpretError, "No file name")
  elif exprList.len == 2:
    let fileName = interpret(exprList[1])
    if fileName.kind == crValueString:
      let content = readFile(fileName.stringVal)
      return CirruValue(kind: crValueString, stringVal: content)
    else:
      raise newException(InterpretError, "Expected path name in string")
  else:
    raise newException(InterpretError, "Too many arguments!")
