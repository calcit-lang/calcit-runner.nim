
import strformat
import system
import tables
import hashes
import options

import ./data
import ./types
import ./helpers
import ./format

proc evalArray*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  var arrayData: seq[CirruData]
  for child in exprList[1..^1]:
    arrayData.add(interpret(child, scope))
  return CirruData(kind: crDataVector, vectorVal: arrayData)

proc evalIf*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  if (exprList.len == 1):
    let node = exprList[0]
    raiseEvalError("No arguments for if", node)
  elif (exprList.len == 2):
    let node = exprList[1]
    raiseEvalError("No arguments for if", node)
  elif (exprList.len == 3):
    let node = exprList[1]
    let cond = interpret(node, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], scope)
      else:
        return CirruData(kind: crDataNil)
    else:
      raiseEvalError("Not a bool in if", node)
  elif (exprList.len == 4):
    let node = exprList[1]
    let cond = interpret(node, scope)
    if cond.kind == crDataBool:
      if cond.boolVal:
        return interpret(exprList[2], scope)
      else:
        return interpret(exprList[3], scope)
    else:
      raiseEvalError("Not a bool in if", node)
  else:
    let node = exprList[0]
    raiseEvalError("Too many arguments for if", node)


proc evalComment*(): CirruData =
  return CirruData(kind: crDataNil)

proc evalArraySlice(value: seq[CirruData], exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
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
    raiseEvalError("Expected cirru expr", exprList)
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
    raiseEvalError("Expected cirru expr", exprList)
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
    raiseEvalError("Expected cirru expr", exprList)
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
    raiseEvalError("Expected cirru expr", exprList)
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

proc processArguments(definedArgs: CirruData, passedArgs: seq[CirruData], scope: CirruDataScope): void =

  var variadic = false
  var splitPosition = -1
  var counter = 0
  for idx, item in definedArgs:
    if item.kind == crDataSymbol and item.symbolVal == "&":
      variadic = true
      if idx.kind != crDataNumber:
        raiseEvalError("Expected a number from for/pairs", idx)
      splitPosition = idx.numberVal.int
      break

  if variadic:
    if passedArgs.len < splitPosition:
      raiseEvalError("No enough arguments", definedArgs)
    if splitPosition != (definedArgs.len - 2):
      raiseEvalError("& should appear before last argument", definedArgs)
    for idx in 0..<splitPosition:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      scope.dict[definedArgName.symbolVal] = passedArgs[idx]
    var varList: seq[CirruData] = @[]
    for idx in splitPosition..<passedArgs.len:
      varList.add passedArgs[idx]
    let varArgName = definedArgs[definedArgs.len - 1]
    if varArgName.kind != crDataSymbol:
      raiseEvalError("Expected var arg in symbol", varArgName)
    scope.dict[varArgName.symbolVal] = CirruData(kind: crDataList, listVal: varList)

  else:
    var counter = 0
    if definedArgs.len != passedArgs.len:
      raiseEvalError("Args length mismatch", definedArgs)
    for arg in definedArgs:
      if arg.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", arg)
      scope.dict[arg.symbolVal] = passedArgs[counter]
      counter += 1

proc evalDefn*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  let f = proc(xs: seq[CirruData], interpret2: EdnEvalFn, scope2: CirruDataScope): CirruData =
    let innerScope = CirruDataScope(parent: some(scope))
    let argsList = exprList[2]

    processArguments(argsList, xs, innerScope)

    var ret = CirruData(kind: crDataNil)
    for child in exprList[3..^1]:
      ret = interpret(child, innerScope)
    return ret

  let code = RefCirruData(kind: crDataList, listVal: getListDataSeq(exprList))
  return CirruData(kind: crDataFn, fnVal: f, fnCode: code)

proc evalLet*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
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
    raiseEvalError("Expected cirru expr", exprList)
  let body = exprList[1..^1]
  result = CirruData(kind: crDataNil)
  for child in body:
    result = interpret(child, scope)

proc evalEval*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseEvalError("eval expects 1 argument", exprList)
  let code = interpret(exprList[1], scope)
  if not checkExprStructure(code):
    raiseEvalError("Expected cirru expr in eval(...)", code)
  dimEcho("eval: ", $code)
  interpret code, scope

# TODO, symbols in macros refers to define scope
proc attachScope(exprList: CirruData, scope: CirruDataScope): CirruData =
  if exprList.kind == crDataSymbol:
    return CirruData(kind: crDataSymbol, symbolVal: exprList.symbolVal, ns: exprList.ns, scope: some(scope))
  elif isListData(exprList):
    var list: seq[CirruData] = @[]
    for item in exprList:
      list.add attachScope(item, scope)
    return CirruData(kind: crDataList, listVal: list)
  else:
    raiseEvalError("Unexpected data for attaching", exprList)

proc evalQuote*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList) or exprList.isSymbol:
    raiseEvalError("Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseEvalError("quote expects 1 argument", exprList)
  let code = attachScope(exprList[1], scope)
  return code

proc replaceExpr(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if exprList.kind == crDataSymbol:
    return exprList
  elif exprList.kind == crDataList:
    var list: seq[CirruData] = @[]
    for item in exprList:
      if item.kind == crDataList:
        let head = item[0]
        if head.symbolVal == "~":
          if item.len != 2:
            raiseEvalError "Expected 1 argument in ~ of quote-replace", item
          list.add interpret(item[1], scope)
        elif head.symbolVal == "~@":
          if item.len != 2:
            raiseEvalError "Expected 1 argument in ~@ of quote-replace", item
          let xs = interpret(item[1], scope)
          if notListData(xs):
            raiseEvalError "Expected list for ~@ of quote-replace", xs
          for x in xs:
            list.add x
        else:
          list.add replaceExpr(item, interpret, scope)
      else:
        list.add replaceExpr(item, interpret, scope)
    return CirruData(kind: crDataList, listVal: list)
  else:
    raiseEvalError("Unknown data in expr", exprList)

proc evalQuoteReplace*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  if exprList.len != 2:
    raiseEvalError("quote-replace expects 1 argument", exprList)

  let ret = replaceExpr(attachScope(exprList[1], scope), interpret, scope)
  if not checkExprStructure(ret):
    raiseEvalError("Unexpected structure from quote-replace", ret)
  ret

proc evalDefmacro*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  let f = proc(xs: seq[CirruData], callingFn: EdnEvalFn, callingScope: CirruDataScope): CirruData =
    let innerScope = CirruDataScope(parent: some(scope))
    let argsList = exprList[2]

    processArguments(argsList, xs, innerScope)

    var ret = CirruData(kind: crDataNil)
    for child in exprList[3..^1]:
      ret = interpret(child, innerScope)
    if notListData(ret):
      raiseEvalError("Expected cirru expr from defmacro", ret)
    return ret

  let code = RefCirruData(kind: crDataList, listVal: getListDataSeq(exprList))
  return CirruData(kind: crDataMacro, macroVal: f, macroCode: code)

proc evalAssert*(exprList: CirruData, interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if notListData(exprList):
    raiseEvalError("Expected cirru expr", exprList)
  if exprList.len != 3:
    raiseEvalError("eval expects 1 argument", exprList)
  let message = interpret(exprList[1], scope)
  if message.kind != crDataString:
    raiseEvalError("Expected assert message in string", exprList[1])
  let target = interpret(exprList[2], scope)
  if target.kind != crDataBool:
    raiseEvalError("Expected assert target in bool", exprList[2])
  if not target.boolVal:
    raiseEvalError(message.stringVal, exprList)
