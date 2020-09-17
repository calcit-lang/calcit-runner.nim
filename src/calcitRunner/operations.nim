
import strformat
import system
import tables
import hashes
import json
import terminal
import options

import cirruParser

import ./data
import ./types
import ./helpers

proc evalAdd*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var ret = 0.0
  for node in exprList[1..^1]:
    let v = interpret(node, ns, scope)
    if v.kind == crDataNumber:
      ret += v.numberVal
    else:
      raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
  return CirruData(kind: crDataNumber, numberVal: ret)

proc evalCompare*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 3:
    raiseInterpretExceptionAtNode(fmt"Too few arguments to compare", exprList)
  let opNode = exprList[0]
  if opNode.kind != cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected compare symbol", exprList)
  var comparator = proc(a, b: float): bool = a == b
  case opNode.text:
  of "<":
    comparator = proc(a, b: float): bool = a < b
  of ">":
    comparator = proc(a, b: float): bool = a > b
  of "=":
    comparator = proc(a, b: float): bool = a == b
  of "!=":
    comparator = proc(a, b: float): bool = a != b
  else:
    raiseInterpretExceptionAtNode(fmt"Unknown compare symbol", opNode)

  let body = exprList.list[1..^1]
  for idx, node in body:
    if idx >= (exprList.len - 2):
      break
    let v = interpret(node, ns, scope)
    if v.kind != crDataNumber:
      raiseInterpretExceptionAtNode(fmt"Not a number {v.kind}", node)
    let vNext = interpret(body[idx + 1], ns, scope)
    if vNext.kind != crDataNumber:
      raiseInterpretExceptionAtNode(fmt"Not a number {v.kind}", body[idx + 1])
    if not comparator(v.numberVal, vNext.numberVal):
      return CirruData(kind: crDataBool, boolVal: false)

  return CirruData(kind: crDataBool, boolVal: true)

proc evalMinus*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if (exprList.len == 1):
    return CirruData(kind: crDataNumber, numberVal: 0)
  elif (exprList.len == 2):
    let node = exprList[1]
    let ret = interpret(node, ns, scope)
    if ret.kind == crDataNumber:
      return ret
    else:
      raiseInterpretException(fmt"Not a number {ret.kind}", node.line, node.column)
  else:
    let node = exprList[1]
    let x0 = interpret(node, ns, scope)
    var ret: float = 0
    if x0.kind == crDataNumber:
      ret = x0.numberVal
    else:
      raiseInterpretException(fmt"Not a number {x0.kind}", node.line, node.column)
    for node in exprList[2..^1]:
      let v = interpret(node, ns, scope)
      if v.kind == crDataNumber:
        ret -= v.numberVal
      else:
        raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
    return CirruData(kind: crDataNumber, numberVal: ret)

proc evalArray*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var arrayData: seq[CirruData]
  for child in exprList[1..^1]:
    arrayData.add(interpret(child, ns, scope))
  return CirruData(kind: crDataVector, vectorVal: arrayData)

proc evalIf*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if (exprList.len == 1):
    let node = exprList[0]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 2):
    let node = exprList[1]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 3):
    let node = exprList[1]
    let cond = interpret(node, ns, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], ns, scope)
      else:
        return CirruData(kind: crDataNil)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  elif (exprList.len == 4):
    let node = exprList[1]
    let cond = interpret(node, ns, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], ns, scope)
      else:
        return interpret(exprList[3], ns, scope)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  else:
    let node = exprList[0]
    raiseInterpretException("Too many arguments for if", node.line, node.column)

proc evalReadFile*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len == 1:
    let node = exprList[0]
    raiseInterpretException("Lack of file name", node.line, node.column)
  elif exprList.len == 2:
    let node = exprList[1]
    let fileName = interpret(node, ns, scope)
    if fileName.kind == crDataString:
      let content = readFile(fileName.stringVal)
      return CirruData(kind: crDataString, stringVal: content)
    else:
      raiseInterpretException("Expected path name in string", node.line, node.column)
  else:
    let node = exprList[2]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalWriteFile*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 3:
    let node = exprList[0]
    raiseInterpretException("Lack of file name or target", node.line, node.column)
  elif exprList.len == 3:
    let node = exprList[1]
    let fileName = interpret(node, ns, scope)
    if fileName.kind != crDataString:
      raiseInterpretException("Expected path name in string", node.line, node.column)
    let contentNode = exprList[2]
    let content = interpret(contentNode, ns, scope)
    if content.kind != crDataString:
      raiseInterpretException("Expected content in string", contentNode.line, contentNode.column)
    writeFile(fileName.stringVal, content.stringVal)

    coloredEcho fgRed, fmt"Wrote to file {fileName.stringVal}"
    return CirruData(kind: crDataNil)
  else:
    let node = exprList[3]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalComment*(): CirruData =
  return CirruData(kind: crDataNil)

proc evalArraySlice(value: seq[CirruData], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len == 2:
    let node = exprList[1]
    raiseInterpretExceptionAtNode("Expression not supported for methods", node)
  if exprList.len > 4:
    let node = exprList[4]
    raiseInterpretExceptionAtNode("Too many arguments for Array slice", node)
  let fromIdx = interpret(exprList[2], ns, scope)
  if fromIdx.kind != crDataNumber:
    raiseInterpretExceptionAtNode("Not a number of from index", exprList[2])

  if fromIdx.numberVal < 0:
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.numberVal}", exprList[2])
  if fromIdx.numberVal > (value.len - 1).float:
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.numberVal} > {value.len-1}", exprList[2])

  if exprList.len == 3:
    return CirruData(kind: crDataVector, vectorVal: value[fromIdx.numberVal..^1])

  let toIdx = interpret(exprList[3], ns, scope)
  if toIdx.kind != crDataNumber:
    raiseInterpretExceptionAtNode("Not a number of to index", exprList[3])
  if toIdx.numberVal < fromIdx.numberVal:
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.numberVal} < {fromIdx.numberVal}", exprList[3])
  if toIdx.numberVal > (value.len - 1).float:
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.numberVal} > {value.len-1}", exprList[3])

  return CirruData(kind: crDataVector, vectorVal: value[fromIdx.numberVal..toIdx.numberVal])

proc evalArrayConcat(value: seq[CirruData], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("Too few arguments", exprList[1])
  var arr: seq[CirruData]
  for idx, child in exprList[2..^1]:
    let item = interpret(child, ns, scope)
    if item.kind != crDataVector:
      raiseInterpretExceptionAtNode("Not an array in concat", exprList[idx + 2])
    for valueItem in item.vectorVal:
      arr.add valueItem

  return CirruData(kind: crDataVector, vectorVal: arr)

proc callArrayMethod*(value: var seq[CirruData], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])
  case exprList[1].text
  of "add":
    for child in exprList[2..^1]:
      let item = interpret(child, ns, scope)
      value.add item
    return CirruData(kind: crDataVector, vectorVal: value)
  of "slice":
    return evalArraySlice(value, exprList, interpret, ns, scope)
  of "concat":
    return evalArrayConcat(value, exprList, interpret, ns, scope)
  of "len":
    return CirruData(kind: crDataNumber, numberVal: value.len().float)
  else:
    raiseInterpretExceptionAtNode("Unknown method" & exprList[1].text, exprList[1])

proc evalTable*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var value = initTable[CirruData, CirruData]()
  for pair in exprList[1..^1]:
    if pair.kind == cirruString:
      raiseInterpretExceptionAtNode("Table requires nested children pairs", pair)
    if pair.list.len() != 2:
      raiseInterpretExceptionAtNode("Each pair of table contains 2 elements", pair)
    let k = interpret(pair.list[0], ns, scope)
    let v = interpret(pair.list[1], ns, scope)
    # TODO, import hash for CirruNode
    # value.add(k, v)
  return CirruData(kind: crDataMap, mapVal: value)

proc callTableMethod*(value: var Table[CirruData, CirruData], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])
  case exprList[1].text
  of "get":
    if exprList.len != 3:
      raiseInterpretExceptionAtNode("Get method expects 1 argument", exprList[1])
    let k = interpret(exprList[2], ns, scope)
    return value[k]

  of "add":
    if exprList.len != 4:
      raiseInterpretExceptionAtNode("Add method expects 2 arguments", exprList[1])
    let k = interpret(exprList[2], ns, scope)
    let v = interpret(exprList[3], ns, scope)
    # value.add(k, v)
    return CirruData(kind: crDataMap, mapVal: value)

  of "del":
    if exprList.len != 3:
      raiseInterpretExceptionAtNode("Del method expects 1 argument", exprList[1])
    let k = interpret(exprList[2], ns, scope)
    value.del(k)
    return CirruData(kind: crDataMap, mapVal: value)

  of "len":
    if exprList.len != 2:
      raiseInterpretExceptionAtNode("Count method expects 0 argument", exprList[1])
    return CirruData(kind: crDataNumber, numberVal: value.len().float)

  else:
    raiseInterpretExceptionAtNode("Unknown method " & exprList[1].text, exprList[1])

proc callStringMethod*(value: string, exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])

  case exprList[1].text
  of "len":
    return CirruData(kind: crDataNumber, numberVal: value.len().float)
  else:
    raiseInterpretExceptionAtNode("Unknown method " & exprList[1].text , exprList[1])

proc evalLoadJson*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("load-json requires relative path to json file", exprList[0])
  let filePath = interpret(exprList[1], ns, scope)
  if filePath.kind != crDataString:
    raiseInterpretExceptionAtNode("load-json requires path in string", exprList[1])
  let content = readFile(filePath.stringVal)
  try:
    let jsonData = parseJson(content)
    return jsonData.toCirruEdn()
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseInterpretExceptionAtNode("Failed to parse file", exprList[1])

proc evalType*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("type gets 1 argument", exprList[0])
  let v = interpret(exprList[1], ns, scope)
  case v.kind
    of crDataNil: CirruData(kind: crDataString, stringVal: "nil")
    of crDataNumber: CirruData(kind: crDataString, stringVal: "int")
    of crDataString: CirruData(kind: crDataString, stringVal: "string")
    of crDataBool: CirruData(kind: crDataString, stringVal: "bool")
    of crDataVector: CirruData(kind: crDataString, stringVal: "array")
    of crDataMap: CirruData(kind: crDataString, stringVal: "table")
    of crDataFn: CirruData(kind: crDataString, stringVal: "fn")
    else: CirruData(kind: crDataString, stringVal: "unknown")

proc evalDefn*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let f = proc(xs: seq[CirruData], interpret2: EdnEvalFn, ns2: string, scope2: CirruDataScope): CirruData =
    let fnScope = CirruDataScope(parent: some(scope))
    let argsList = exprList[2]
    var counter = 0
    if argsList.len != xs.len:
      raiseInterpretExceptionAtNode(fmt"Args length mismatch", argsList)
    for arg in argsList:
      if arg.kind != cirruString:
        raiseInterpretExceptionAtNode(fmt"Expects arg in string", arg)
      fnScope.dict[arg.text] = xs[counter]
      counter += 1
    var ret = CirruData(kind: crDataNil)
    for child in exprList[3..^1]:
      ret = interpret(child, ns, fnScope)
    return ret

  return CirruData(kind: crDataFn, fnVal: f)

proc evalLet*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let letScope = CirruDataScope(parent: some(scope))
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough code for let, too short", exprList[0])
  let pairs = exprList[1]
  let body = exprList[2..^1]
  if pairs.kind != cirruSeq:
    raiseInterpretExceptionAtNode("Expect bindings in a vector", pairs)
  for pair in pairs.list:
    if pair.kind != cirruSeq:
      raiseInterpretExceptionAtNode("Expect binding in a vector", pair)
    if pair.list.len != 2:
      raiseInterpretExceptionAtNode("Expect binding in length 2", pair)
    let name = pair.list[0]
    let value = pair.list[1]
    if name.kind != cirruString:
      raiseInterpretExceptionAtNode("Expecting binding name in string", name)
    letScope.dict[name.text] = interpret(value, ns, letScope)
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, ns, letScope)

proc evalDo*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruDataScope): CirruData =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let body = exprList[1..^1]
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, ns, scope)
