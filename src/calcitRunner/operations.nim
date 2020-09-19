
import strformat
import system
import tables
import hashes
import json
import terminal
import options

import ./data
import ./types
import ./helpers

proc evalAdd*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  var ret = 0.0
  for node in exprList[1..^1]:
    let v = interpret(node, scope)
    if v.kind == crDataNumber:
      ret += v.numberVal
    else:
      raiseEvalError(fmt"Not a number {v.kind}", node)
  return CirruData(kind: crDataNumber, numberVal: ret)

proc evalCompare*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 3:
    raiseEvalError(fmt"Too few arguments to compare", exprList)
  let opNode = exprList[0]
  if opNode.kind != crDataSymbol:
    raiseEvalError(fmt"Expected compare symbol", exprList)
  var comparator = proc(a, b: float): bool = a == b
  case opNode.symbolVal:
  of "<":
    comparator = proc(a, b: float): bool = a < b
  of ">":
    comparator = proc(a, b: float): bool = a > b
  of "=":
    comparator = proc(a, b: float): bool = a == b
  of "!=":
    comparator = proc(a, b: float): bool = a != b
  else:
    raiseEvalError(fmt"Unknown compare symbol", opNode)

  let body = exprList[1..^1]
  for idx, node in body:
    if idx >= (exprList.len - 2):
      break
    let v = interpret(node, scope)
    if v.kind != crDataNumber:
      raiseEvalError(fmt"Not a number {v.kind}", node)
    let vNext = interpret(body[idx + 1], scope)
    if vNext.kind != crDataNumber:
      raiseEvalError(fmt"Not a number {v.kind}", body[idx + 1])
    if not comparator(v.numberVal, vNext.numberVal):
      return CirruData(kind: crDataBool, boolVal: false)

  return CirruData(kind: crDataBool, boolVal: true)

proc evalMinus*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if (exprList.len == 1):
    return CirruData(kind: crDataNumber, numberVal: 0)
  elif (exprList.len == 2):
    let node = exprList[1]
    let ret = interpret(node, scope)
    if ret.kind == crDataNumber:
      return ret
    else:
      raiseInterpretException(fmt"Not a number {ret.kind}", node.line, node.column)
  else:
    let node = exprList[1]
    let x0 = interpret(node, scope)
    var ret: float = 0
    if x0.kind == crDataNumber:
      ret = x0.numberVal
    else:
      raiseInterpretException(fmt"Not a number {x0.kind}", node.line, node.column)
    for node in exprList[2..^1]:
      let v = interpret(node, scope)
      if v.kind == crDataNumber:
        ret -= v.numberVal
      else:
        raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
    return CirruData(kind: crDataNumber, numberVal: ret)

proc evalArray*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  var arrayData: seq[CirruData]
  for child in exprList[1..^1]:
    arrayData.add(interpret(child, scope))
  return CirruData(kind: crDataVector, vectorVal: arrayData)

proc evalIf*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if (exprList.len == 1):
    let node = exprList[0]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 2):
    let node = exprList[1]
    raiseInterpretException("No arguments for if", node.line, node.column)
  elif (exprList.len == 3):
    let node = exprList[1]
    let cond = interpret(node, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], scope)
      else:
        return CirruData(kind: crDataNil)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  elif (exprList.len == 4):
    let node = exprList[1]
    let cond = interpret(node, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], scope)
      else:
        return interpret(exprList[3], scope)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  else:
    let node = exprList[0]
    raiseInterpretException("Too many arguments for if", node.line, node.column)

proc evalReadFile*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len == 1:
    let node = exprList[0]
    raiseInterpretException("Lack of file name", node.line, node.column)
  elif exprList.len == 2:
    let node = exprList[1]
    let fileName = interpret(node, scope)
    if fileName.kind == crDataSymbol:
      let content = readFile(fileName.symbolVal)
      return CirruData(kind: crDataString, stringVal: content)
    else:
      raiseInterpretException("Expected path name in string", node.line, node.column)
  else:
    let node = exprList[2]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalWriteFile*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 3:
    let node = exprList[0]
    raiseInterpretException("Lack of file name or target", node.line, node.column)
  elif exprList.len == 3:
    let node = exprList[1]
    let fileName = interpret(node, scope)
    if fileName.kind != crDataSymbol:
      raiseInterpretException("Expected path name in string", node.line, node.column)
    let contentNode = exprList[2]
    let content = interpret(contentNode, scope)
    if content.kind != crDataSymbol:
      raiseInterpretException("Expected content in string", contentNode.line, contentNode.column)
    writeFile(fileName.symbolVal, content.symbolVal)

    coloredEcho fgRed, fmt"Wrote to file {fileName.symbolVal}"
    return CirruData(kind: crDataNil)
  else:
    let node = exprList[3]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalComment*(): CirruData =
  return CirruData(kind: crDataNil)

proc evalArraySlice(value: seq[CirruData], exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len == 2:
    let node = exprList[1]
    raiseEvalError("Expression not supported for methods", node)
  if exprList.len > 4:
    let node = exprList[4]
    raiseEvalError("Too many arguments for Array slice", node)
  let fromIdx = interpret(exprList[2], scope)
  if fromIdx.kind != crDataNumber:
    raiseEvalError("Not a number of from index", exprList[2])

  if fromIdx.numberVal < 0:
    raiseEvalError(fmt"From index out of index {fromIdx.numberVal}", exprList[2])
  if fromIdx.numberVal > (value.len - 1).float:
    raiseEvalError(fmt"From index out of index {fromIdx.numberVal} > {value.len-1}", exprList[2])

  if exprList.len == 3:
    return CirruData(kind: crDataVector, vectorVal: value[fromIdx.numberVal..^1])

  let toIdx = interpret(exprList[3], scope)
  if toIdx.kind != crDataNumber:
    raiseEvalError("Not a number of to index", exprList[3])
  if toIdx.numberVal < fromIdx.numberVal:
    raiseEvalError(fmt"To index out of index {toIdx.numberVal} < {fromIdx.numberVal}", exprList[3])
  if toIdx.numberVal > (value.len - 1).float:
    raiseEvalError(fmt"To index out of index {toIdx.numberVal} > {value.len-1}", exprList[3])

  return CirruData(kind: crDataVector, vectorVal: value[fromIdx.numberVal..toIdx.numberVal])

proc evalArrayConcat(value: seq[CirruData], exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseEvalError("Too few arguments", exprList[1])
  var arr: seq[CirruData]
  for idx, child in exprList[2..^1]:
    let item = interpret(child, scope)
    if item.kind != crDataVector:
      raiseEvalError("Not an array in concat", exprList[idx + 2])
    for valueItem in item.vectorVal:
      arr.add valueItem

  return CirruData(kind: crDataVector, vectorVal: arr)

proc callArrayMethod*(value: var seq[CirruData], exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseEvalError("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind != crDataSymbol:
    raiseEvalError("Expression not supported for methods", exprList[1])
  case exprList[1].symbolVal
  of "add":
    for child in exprList[2..^1]:
      let item = interpret(child, scope)
      value.add item
    return CirruData(kind: crDataVector, vectorVal: value)
  of "slice":
    return evalArraySlice(value, exprList, interpret, scope)
  of "concat":
    return evalArrayConcat(value, exprList, interpret, scope)
  of "len":
    return CirruData(kind: crDataNumber, numberVal: value.len().float)
  else:
    raiseEvalError("Unknown method" & exprList[1].symbolVal, exprList[1])

proc evalTable*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  var value = initTable[CirruData, CirruData]()
  for pair in exprList[1..^1]:
    if pair.kind != crDataList and pair.kind != crDataVector:
      raiseEvalError("Table requires nested children pairs", pair)
    if pair.len() != 2:
      raiseEvalError("Each pair of table contains 2 elements", pair)
    let k = interpret(pair[0], scope)
    let v = interpret(pair[1], scope)
    # TODO, import hash for CirruData
    # value.add(k, v)
  return CirruData(kind: crDataMap, mapVal: value)

proc callTableMethod*(value: var Table[CirruData, CirruData], exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseEvalError("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind != crDataSymbol:
    raiseEvalError("Expression not supported for methods", exprList[1])
  case exprList[1].symbolVal
  of "get":
    if exprList.len != 3:
      raiseEvalError("Get method expects 1 argument", exprList[1])
    let k = interpret(exprList[2], scope)
    return value[k]

  of "add":
    if exprList.len != 4:
      raiseEvalError("Add method expects 2 arguments", exprList[1])
    let k = interpret(exprList[2], scope)
    let v = interpret(exprList[3], scope)
    # value.add(k, v)
    return CirruData(kind: crDataMap, mapVal: value)

  of "del":
    if exprList.len != 3:
      raiseEvalError("Del method expects 1 argument", exprList[1])
    let k = interpret(exprList[2], scope)
    value.del(k)
    return CirruData(kind: crDataMap, mapVal: value)

  of "len":
    if exprList.len != 2:
      raiseEvalError("Count method expects 0 argument", exprList[1])
    return CirruData(kind: crDataNumber, numberVal: value.len().float)

  else:
    raiseEvalError("Unknown method " & exprList[1].symbolVal, exprList[1])

proc callStringMethod*(value: string, exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseEvalError("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind != crDataSymbol:
    raiseEvalError("Expression not supported for methods", exprList[1])

  case exprList[1].symbolVal
  of "len":
    return CirruData(kind: crDataNumber, numberVal: value.len().float)
  else:
    raiseEvalError("Unknown method " & exprList[1].symbolVal , exprList[1])

proc evalLoadJson*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseEvalError("load-json requires relative path to json file", exprList[0])
  let filePath = interpret(exprList[1], scope)
  if filePath.kind != crDataSymbol:
    raiseEvalError("load-json requires path in string", exprList[1])
  let content = readFile(filePath.symbolVal)
  try:
    let jsonData = parseJson(content)
    return jsonData.toCirruData()
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseEvalError("Failed to parse file", exprList[1])

proc evalType*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseEvalError("type gets 1 argument", exprList[0])
  let v = interpret(exprList[1], scope)
  case v.kind
    of crDataNil: CirruData(kind: crDataString, stringVal: "nil")
    of crDataNumber: CirruData(kind: crDataString, stringVal: "int")
    of crDataString: CirruData(kind: crDataString, stringVal: "string")
    of crDataBool: CirruData(kind: crDataString, stringVal: "bool")
    of crDataVector: CirruData(kind: crDataString, stringVal: "array")
    of crDataMap: CirruData(kind: crDataString, stringVal: "table")
    of crDataFn: CirruData(kind: crDataString, stringVal: "fn")
    else: CirruData(kind: crDataString, stringVal: "unknown")

proc evalDefn*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  let f = proc(xs: seq[CirruData], interpret2: EdnEvalFn, scope2: CirruDataScope): CirruData =
    let fnScope = CirruDataScope(parent: some(scope))
    let argsList = exprList[2]
    var counter = 0
    if argsList.len != xs.len:
      raiseEvalError(fmt"Args length mismatch", argsList)
    for arg in argsList:
      if arg.kind != crDataSymbol:
        raiseEvalError(fmt"Expects arg in string", arg)
      fnScope.dict[arg.symbolVal] = xs[counter]
      counter += 1
    var ret = CirruData(kind: crDataNil)
    for child in exprList[3..^1]:
      ret = interpret(child, fnScope)
    return ret

  return CirruData(kind: crDataFn, fnVal: f)

proc evalLet*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  let letScope = CirruDataScope(parent: some(scope))
  if exprList.len < 2:
    raiseEvalError("No enough code for let, too short", exprList[0])
  let pairs = exprList[1]
  let body = exprList[2..^1]
  if pairs.kind != crDataList and pairs.kind != crDataVector:
    raiseEvalError("Expect bindings in a vector", pairs)
  for pair in pairs:
    if pair.kind != crDataList and pair.kind != crDataVector:
      raiseEvalError("Expect binding in a vector", pair)
    if pair.len != 2:
      raiseEvalError("Expect binding in length 2", pair)
    let name = pair[0]
    let value = pair[1]
    if name.kind != crDataSymbol:
      raiseEvalError("Expecting binding name in string", name)
    letScope.dict[name.symbolVal] = interpret(value, letScope)
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, letScope)

proc evalDo*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError(fmt"Expected cirru expr", exprList)
  let body = exprList[1..^1]
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, scope)
