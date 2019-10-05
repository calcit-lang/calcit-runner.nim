
import os
import re
import cirruParser
import sequtils
from strutils import join, parseInt
import math
import strformat
import system
import ./types
import ./helpers
import terminal
import tables
import hashes

type fnInterpret = proc(expr: CirruNode): CirruValue

proc evalAdd*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  var ret = 0
  for node in exprList[1..^1]:
    let v = interpret(node)
    if v.kind == crValueInt:
      ret += v.intVal
    else:
      raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
  return CirruValue(kind: crValueInt, intVal: ret)

proc evalMinus*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
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

proc evalArray*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  var arrayData: seq[CirruValue]
  for child in exprList[1..^1]:
    arrayData.add(interpret(child))
  return CirruValue(kind: crValueArray, arrayVal: arrayData)

proc evalIf*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
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

proc evalReadFile*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len == 1:
    let node = exprList[0]
    raiseInterpretException("Lack of file name", node.line, node.column)
  elif exprList.len == 2:
    let node = exprList[1]
    let fileName = interpret(node)
    if fileName.kind == crValueString:
      let content = readFile(fileName.stringVal)
      return CirruValue(kind: crValueString, stringVal: content)
    else:
      raiseInterpretException("Expected path name in string", node.line, node.column)
  else:
    let node = exprList[2]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalWriteFile*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len < 3:
    let node = exprList[0]
    raiseInterpretException("Lack of file name or target", node.line, node.column)
  elif exprList.len == 3:
    let node = exprList[1]
    let fileName = interpret(node)
    if fileName.kind != crValueString:
      raiseInterpretException("Expected path name in string", node.line, node.column)
    let contentNode = exprList[2]
    let content = interpret(contentNode)
    if content.kind != crValueString:
      raiseInterpretException("Expected content in string", contentNode.line, contentNode.column)
    writeFile(fileName.stringVal, content.stringVal)
    setForegroundColor(fgCyan)
    echo fmt"Wrote to file {fileName.stringVal}"
    resetAttributes()
    return CirruValue(kind: crValueNil)
  else:
    let node = exprList[3]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalComment*(): CirruValue =
  return CirruValue(kind: crValueNil)

proc evalArraySlice(value: seq[CirruValue], exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len == 2:
    let node = exprList[1]
    raiseInterpretExceptionAtNode("Expression not supported for methods", node)
  if exprList.len > 4:
    let node = exprList[4]
    raiseInterpretExceptionAtNode("Too many arguments for Array slice", node)
  let fromIdx = interpret(exprList[2])
  if fromIdx.kind != crValueInt:
    raiseInterpretExceptionAtNode("Not a number of from index", exprList[2])

  if fromIdx.intVal < 0:
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.intVal}", exprList[2])
  if fromIdx.intVal > (value.len - 1):
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.intVal} > {value.len-1}", exprList[2])

  if exprList.len == 3:
    return CirruValue(kind: crValueArray, arrayVal: value[fromIdx.intVal..^1])

  let toIdx = interpret(exprList[3])
  if toIdx.kind != crValueInt:
    raiseInterpretExceptionAtNode("Not a number of to index", exprList[3])
  if toIdx.intVal < fromIdx.intVal:
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.intVal} < {fromIdx.intVal}", exprList[3])
  if toIdx.intVal > (value.len - 1):
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.intVal} > {value.len-1}", exprList[3])

  return CirruValue(kind: crValueArray, arrayVal: value[fromIdx.intVal..toIdx.intVal])

proc evalArrayConcat(value: seq[CirruValue], exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("Too few arguments", exprList[1])
  var arr: seq[CirruValue]
  for idx, child in exprList[2..^1]:
    let item = interpret(child)
    if item.kind != crValueArray:
      raiseInterpretExceptionAtNode("Not an array in concat", exprList[idx + 2])
    for valueItem in item.arrayVal:
      arr.add valueItem

  return CirruValue(kind: crValueArray, arrayVal: arr)

proc callArrayMethod*(value: var seq[CirruValue], exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])
  case exprList[1].text
  of "add":
    for child in exprList[2..^1]:
      let item = interpret(child)
      value.add item
    return CirruValue(kind: crValueArray, arrayVal: value)
  of "slice":
    return evalArraySlice(value, exprList, interpret)
  of "concat":
    return evalArrayConcat(value, exprList, interpret)
  else:
    raiseInterpretExceptionAtNode("Unknown method", exprList[1])

proc evalTable*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  var value = initTable[Hash, CirruValue]()
  for pair in exprList[1..^1]:
    if pair.kind == cirruString:
      raiseInterpretExceptionAtNode("Table requires nested children pairs", pair)
    if pair.list.len() != 2:
      raiseInterpretExceptionAtNode("Each pair of table contains 2 elements", pair)
    let k = interpret(pair.list[0])
    let v = interpret(pair.list[1])
    value.add(hashCirruValue(k), v)
  return CirruValue(kind: crValueTable, tableVal: value)
