
import strformat
import system
import tables
import hashes
import json
import terminal
import options

import cirruParser
import cirruEdn

import ./helpers

proc evalAdd*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var ret = 0.0
  for node in exprList[1..^1]:
    let v = interpret(node, ns, scope)
    if v.kind == crEdnNumber:
      ret += v.numberVal
    else:
      raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
  return CirruEdnValue(kind: crEdnNumber, numberVal: ret)

proc evalMinus*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if (exprList.len == 1):
    return CirruEdnValue(kind: crEdnNumber, numberVal: 0)
  elif (exprList.len == 2):
    let node = exprList[1]
    let ret = interpret(node, ns, scope)
    if ret.kind == crEdnNumber:
      return ret
    else:
      raiseInterpretException(fmt"Not a number {ret.kind}", node.line, node.column)
  else:
    let node = exprList[1]
    let x0 = interpret(node, ns, scope)
    var ret: float = 0
    if x0.kind == crEdnNumber:
      ret = x0.numberVal
    else:
      raiseInterpretException(fmt"Not a number {x0.kind}", node.line, node.column)
    for node in exprList[2..^1]:
      let v = interpret(node, ns, scope)
      if v.kind == crEdnNumber:
        ret -= v.numberVal
      else:
        raiseInterpretException(fmt"Not a number {v.kind}", node.line, node.column)
    return CirruEdnValue(kind: crEdnNumber, numberVal: ret)

proc evalArray*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var arrayData: seq[CirruEdnValue]
  for child in exprList[1..^1]:
    arrayData.add(interpret(child, ns, scope))
  return CirruEdnValue(kind: crEdnVector, vectorVal: arrayData)

proc evalIf*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
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
    if cond.kind == crEdnBool:
      if cond.boolVal:
        return interpret(exprList[2], ns, scope)
      else:
        return CirruEdnValue(kind: crEdnNil)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  elif (exprList.len == 4):
    let node = exprList[1]
    let cond = interpret(node, ns, scope)
    if cond.kind == crEdnBool:
      if cond.boolVal:
        return interpret(exprList[2], ns, scope)
      else:
        return interpret(exprList[3], ns, scope)
    else:
      raiseInterpretException("Not a bool in if", node.line, node.column)
  else:
    let node = exprList[0]
    raiseInterpretException("Too many arguments for if", node.line, node.column)

proc evalReadFile*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len == 1:
    let node = exprList[0]
    raiseInterpretException("Lack of file name", node.line, node.column)
  elif exprList.len == 2:
    let node = exprList[1]
    let fileName = interpret(node, ns, scope)
    if fileName.kind == crEdnString:
      let content = readFile(fileName.stringVal)
      return CirruEdnValue(kind: crEdnString, stringVal: content)
    else:
      raiseInterpretException("Expected path name in string", node.line, node.column)
  else:
    let node = exprList[2]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalWriteFile*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 3:
    let node = exprList[0]
    raiseInterpretException("Lack of file name or target", node.line, node.column)
  elif exprList.len == 3:
    let node = exprList[1]
    let fileName = interpret(node, ns, scope)
    if fileName.kind != crEdnString:
      raiseInterpretException("Expected path name in string", node.line, node.column)
    let contentNode = exprList[2]
    let content = interpret(contentNode, ns, scope)
    if content.kind != crEdnString:
      raiseInterpretException("Expected content in string", contentNode.line, contentNode.column)
    writeFile(fileName.stringVal, content.stringVal)

    coloredEcho fgRed, fmt"Wrote to file {fileName.stringVal}"
    return CirruEdnValue(kind: crEdnNil)
  else:
    let node = exprList[3]
    raiseInterpretException("Too many arguments!", node.line, node.column)

proc evalComment*(): CirruEdnValue =
  return CirruEdnValue(kind: crEdnNil)

proc evalArraySlice(value: seq[CirruEdnValue], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len == 2:
    let node = exprList[1]
    raiseInterpretExceptionAtNode("Expression not supported for methods", node)
  if exprList.len > 4:
    let node = exprList[4]
    raiseInterpretExceptionAtNode("Too many arguments for Array slice", node)
  let fromIdx = interpret(exprList[2], ns, scope)
  if fromIdx.kind != crEdnNumber:
    raiseInterpretExceptionAtNode("Not a number of from index", exprList[2])

  if fromIdx.numberVal < 0:
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.numberVal}", exprList[2])
  if fromIdx.numberVal > (value.len - 1).float:
    raiseInterpretExceptionAtNode(fmt"From index out of index {fromIdx.numberVal} > {value.len-1}", exprList[2])

  if exprList.len == 3:
    return CirruEdnValue(kind: crEdnVector, vectorVal: value[fromIdx.numberVal..^1])

  let toIdx = interpret(exprList[3], ns, scope)
  if toIdx.kind != crEdnNumber:
    raiseInterpretExceptionAtNode("Not a number of to index", exprList[3])
  if toIdx.numberVal < fromIdx.numberVal:
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.numberVal} < {fromIdx.numberVal}", exprList[3])
  if toIdx.numberVal > (value.len - 1).float:
    raiseInterpretExceptionAtNode(fmt"To index out of index {toIdx.numberVal} > {value.len-1}", exprList[3])

  return CirruEdnValue(kind: crEdnVector, vectorVal: value[fromIdx.numberVal..toIdx.numberVal])

proc evalArrayConcat(value: seq[CirruEdnValue], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("Too few arguments", exprList[1])
  var arr: seq[CirruEdnValue]
  for idx, child in exprList[2..^1]:
    let item = interpret(child, ns, scope)
    if item.kind != crEdnVector:
      raiseInterpretExceptionAtNode("Not an array in concat", exprList[idx + 2])
    for valueItem in item.vectorVal:
      arr.add valueItem

  return CirruEdnValue(kind: crEdnVector, vectorVal: arr)

proc callArrayMethod*(value: var seq[CirruEdnValue], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
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
    return CirruEdnValue(kind: crEdnVector, vectorVal: value)
  of "slice":
    return evalArraySlice(value, exprList, interpret, ns, scope)
  of "concat":
    return evalArrayConcat(value, exprList, interpret, ns, scope)
  of "len":
    return CirruEdnValue(kind: crEdnNumber, numberVal: value.len().float)
  else:
    raiseInterpretExceptionAtNode("Unknown method" & exprList[1].text, exprList[1])

proc evalTable*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  var value = initTable[CirruEdnValue, CirruEdnValue]()
  for pair in exprList[1..^1]:
    if pair.kind == cirruString:
      raiseInterpretExceptionAtNode("Table requires nested children pairs", pair)
    if pair.list.len() != 2:
      raiseInterpretExceptionAtNode("Each pair of table contains 2 elements", pair)
    let k = interpret(pair.list[0], ns, scope)
    let v = interpret(pair.list[1], ns, scope)
    # TODO, import hash for CirruNode
    # value.add(k, v)
  return CirruEdnValue(kind: crEdnMap, mapVal: value)

proc callTableMethod*(value: var Table[CirruEdnValue, CirruEdnValue], exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
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
    return CirruEdnValue(kind: crEdnMap, mapVal: value)

  of "del":
    if exprList.len != 3:
      raiseInterpretExceptionAtNode("Del method expects 1 argument", exprList[1])
    let k = interpret(exprList[2], ns, scope)
    value.del(k)
    return CirruEdnValue(kind: crEdnMap, mapVal: value)

  of "len":
    if exprList.len != 2:
      raiseInterpretExceptionAtNode("Count method expects 0 argument", exprList[1])
    return CirruEdnValue(kind: crEdnNumber, numberVal: value.len().float)

  else:
    raiseInterpretExceptionAtNode("Unknown method " & exprList[1].text, exprList[1])

proc callStringMethod*(value: string, exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len < 2:
    raiseInterpretExceptionAtNode("No enough arguments for calling methods", exprList[1])
  if exprList[1].kind == cirruSeq:
    raiseInterpretExceptionAtNode("Expression not supported for methods", exprList[1])

  case exprList[1].text
  of "len":
    return CirruEdnValue(kind: crEdnNumber, numberVal: value.len().float)
  else:
    raiseInterpretExceptionAtNode("Unknown method " & exprList[1].text , exprList[1])

proc evalLoadJson*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("load-json requires relative path to json file", exprList[0])
  let filePath = interpret(exprList[1], ns, scope)
  if filePath.kind != crEdnString:
    raiseInterpretExceptionAtNode("load-json requires path in string", exprList[1])
  let content = readFile(filePath.stringVal)
  try:
    let jsonData = parseJson(content)
    return jsonData.toCirruEdn()
  except JsonParsingError as e:
    echo "Failed to parse"
    raiseInterpretExceptionAtNode("Failed to parse file", exprList[1])

proc evalType*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseInterpretExceptionAtNode("type gets 1 argument", exprList[0])
  let v = interpret(exprList[1], ns, scope)
  case v.kind
    of crEdnNil: CirruEdnValue(kind: crEdnString, stringVal: "nil")
    of crEdnNumber: CirruEdnValue(kind: crEdnString, stringVal: "int")
    of crEdnString: CirruEdnValue(kind: crEdnString, stringVal: "string")
    of crEdnBool: CirruEdnValue(kind: crEdnString, stringVal: "bool")
    of crEdnVector: CirruEdnValue(kind: crEdnString, stringVal: "array")
    of crEdnMap: CirruEdnValue(kind: crEdnString, stringVal: "table")
    of crEdnFn: CirruEdnValue(kind: crEdnString, stringVal: "fn")
    else: CirruEdnValue(kind: crEdnString, stringVal: "unknown")

proc evalDefn*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let f = proc(xs: seq[CirruEdnValue], interpret2: EdnEvalFn, ns2: string, scope2: CirruEdnScope): CirruEdnValue =
    echo "TODO, arguments not handled, scope not handled"
    var ret = CirruEdnValue(kind: crEdnNil)
    for child in exprList[3..^1]:
      # echo "code: ", child
      ret = interpret(child, ns2, scope2)
    return ret

  return CirruEdnValue(kind: crEdnFn, fnVal: f)

proc evalLet*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let letScope = CirruEdnScope(parent: some(scope))
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
  result = CirruEdnValue(kind: crEdnNil)
  for child in body:
    result = interpret(child, ns, letScope)


proc evalDo*(exprList: CirruNode, interpret: EdnEvalFn, ns: string, scope: CirruEdnScope): CirruEdnValue =
  if exprList.kind == cirruString:
    raiseInterpretExceptionAtNode(fmt"Expected cirru expr", exprList)
  let body = exprList[1..^1]
  result = CirruEdnValue(kind: crEdnNil)
  for child in body:
    result = interpret(child, ns, scope)
