
import strformat
import system
import tables
import hashes
import json
import terminal

import cirruParser

import ./types
import ./helpers

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
  of "len":
    return CirruValue(kind: crValueInt, intVal: value.len())
  else:
    raiseInterpretExceptionAtNode("Unknown method", exprList[1])

proc evalTable*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  var value = initTable[Hash, TablePair]()
  for pair in exprList[1..^1]:
    if pair.kind == cirruString:
      raiseInterpretExceptionAtNode("Table requires nested children pairs", pair)
    if pair.list.len() != 2:
      raiseInterpretExceptionAtNode("Each pair of table contains 2 elements", pair)
    let k = interpret(pair.list[0])
    let v = interpret(pair.list[1])
    let valuePair: TablePair = (k, v)
    value.add(hashCirruValue(k), valuePair)
  return CirruValue(kind: crValueTable, tableVal: value)

proc callTableMethod*(value: var Table[Hash, TablePair], exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])
  case exprList[1].text
  of "get":
    if exprList.len != 3:
      raiseInterpretExceptionAtNode("Get method expects 1 argument", exprList[1])
    let k = interpret(exprList[2])
    return value[hashCirruValue(k)].value

  of "add":
    if exprList.len != 4:
      raiseInterpretExceptionAtNode("Add method expects 2 arguments", exprList[1])
    let k = interpret(exprList[2])
    let v = interpret(exprList[3])

    let valuePair: TablePair = (k, v)
    value.add(hashCirruValue(k), valuePair)
    return CirruValue(kind: crValueTable, tableVal: value)

  of "del":
    if exprList.len != 3:
      raiseInterpretExceptionAtNode("Del method expects 1 argument", exprList[1])
    let k = interpret(exprList[2])
    value.del(hashCirruValue(k))
    return CirruValue(kind: crValueTable, tableVal: value)

  of "len":
    if exprList.len != 2:
      raiseInterpretExceptionAtNode("Count method expects 0 argument", exprList[1])
    return CirruValue(kind: crValueInt, intVal: value.len())

  else:
    raiseInterpretExceptionAtNode("Unknown method", exprList[1])

proc callStringMethod*(value: string, exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])

  case exprList[1].text
  of "len":
    return CirruValue(kind: crValueInt, intVal: value.len())
  else:
    raiseInterpretExceptionAtNode("Unknown method", exprList[1])

proc evalLoadJson*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("load-json requires relative path to json file", exprList[0])
  let filePath = interpret(exprList[1])
  if filePath.kind != crValueString:
    raiseInterpretExceptionAtNode("load-json requires path in string", exprList[1])
  let content = readFile(filePath.stringVal)
  try:
    let jsonData = parseJson(content)
    echo jsonData
    return valueFromJson(jsonData)
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseInterpretExceptionAtNode("Failed to parse file", exprList[1])

proc evalType*(exprList: seq[CirruNode], interpret: fnInterpret): CirruValue =
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("type gets 1 argument", exprList[0])
  let v = interpret(exprList[1])
  case v.kind
    of crValueNil: CirruValue(kind: crValueString, stringVal: "nil")
    of crValueInt: CirruValue(kind: crValueString, stringVal: "int")
    of crValueFloat: CirruValue(kind: crValueString, stringVal: "float")
    of crValueString: CirruValue(kind: crValueString, stringVal: "string")
    of crValueBool: CirruValue(kind: crValueString, stringVal: "bool")
    of crValueArray: CirruValue(kind: crValueString, stringVal: "array")
    of crValueTable: CirruValue(kind: crValueString, stringVal: "table")
    of crValueFn: CirruValue(kind: crValueString, stringVal: "fn")
    else: CirruValue(kind: crValueString, stringVal: "unknown")
