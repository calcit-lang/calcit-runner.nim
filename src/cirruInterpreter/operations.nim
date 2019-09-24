
import os
import re
import cirruParser
import sequtils
from strutils import join, parseInt
import math
import strformat
import ./types
import ./helpers

proc evalAdd*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  var ret = 0
  for node in exprList[1..^1]:
    let v = interpret(node)
    if v.kind == crValueInt:
      ret += v.intVal
    else:
      raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
  return CirruValue(kind: crValueInt, intVal: ret)

proc evalMinus*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if (exprList.len == 1):
    return CirruValue(kind: crValueInt, intVal: 0)
  elif (exprList.len == 2):
    let node = exprList[1]
    let ret = interpret(node)
    if ret.kind == crValueInt:
      return ret
    else:
      raiseInterpretException(fmt"Not a number {ret.kind}", node.line, node.column)
  else:
    let node = exprList[1]
    let x0 = interpret(node)
    var ret = 0
    if x0.kind == crValueInt:
      ret = x0.intVal
    else:
      raiseInterpretException(fmt"Not a number {x0.kind}", node.line, node.column)
    for node in exprList[2..^1]:
      let v = interpret(node)
      if v.kind == crValueInt:
        ret -= v.intVal
      else:
        raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
    return CirruValue(kind: crValueInt, intVal: ret)

proc evalIf*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if (exprList.len == 1):
    let node = exprList[0]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 2):
    let node = exprList[1]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 3):
    let node = exprList[1]
    let cond = interpret(node)
    if cond.kind == crValueBool:
      if cond.boolVal:
        return interpret(exprList[2])
      else:
        return CirruValue(kind: crValueNil)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  elif (exprList.len == 4):
    let node = exprList[1]
    let cond = interpret(node)
    if cond.kind == crValueBool:
      if cond.boolVal:
        return interpret(exprList[2])
      else:
        return interpret(exprList[3])
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  else:
    let node = exprList[0]
    raiseInterpretException("Too many arguments for if", node.line, node.column)

proc evalReadFile*(exprList: seq[CirruNode], interpret: proc(expr: CirruNode): CirruValue): CirruValue =
  if exprList.len == 1:
    raiseInterpretException("Too many arguments for if", 0, 0)
  elif exprList.len == 2:
    let fileName = interpret(exprList[1])
    if fileName.kind == crValueString:
      let content = readFile(fileName.stringVal)
      return CirruValue(kind: crValueString, stringVal: content)
    else:
      raise newException(CirruCommandError, "Expected path name in string")
  else:
    raise newException(CirruCommandError, "Too many arguments!")
