import tables
import hashes
import sets
import options
import system
import terminal
import sequtils
import re
import math
import strutils
import json
import strformat

import cirru_parser
import cirru_edn
import ternary_tree

import ./types
import ./helpers

proc hash*(value: CirruData): Hash =
  case value.kind
    of crDataNumber:
      return hash("number:" & $value.numberVal)
    of crDataString:
      return hash("string:" & value.stringVal)
    of crDataNil:
      return hash("nil:")
    of crDataBool:
      return hash("bool:" & $(value.boolVal))
    of crDataKeyword:
      return hash("keyword:" & value.keywordVal)
    of crDataFn:
      result = hash("fn:")
      result = result !& hash(value.fnVal)
      result = !$ result
    of crDataSyntax:
      result = hash("syntax:")
      result = result !& hash(value.syntaxVal)
      result = !$ result
    of crDataMacro:
      result = hash("macro:")
      result = result !& hash(value.macroVal)
      result = !$ result
    of crDataList:
      result = hash("list:")
      for x in value.listVal:
        result = result !& hash(x)
      result = !$ result
    of crDataSet:
      result = hash("set:")
      for x in value.setVal.items:
        result = result !& hash(x)
      result = !$ result
    of crDataMap:
      result = hash("map:")
      for k, v in value.mapVal.pairs:
        result = result !& hash(k)
        result = result !& hash(v)

      result = !$ result

    of crDataSymbol:
      result =  hash("symbol:")
      result = result !& hash(value.symbolVal)
      result = !$ result
    of crDataRecur:
      result =  hash("recur:")
      result = result !& hash(value.args)
      result = !$ result


proc `==`*(x, y: CirruData): bool =
  if x.kind != y.kind:
    return false
  else:
    case x.kind:
    of crDataNil:
      return true
    of crDataBool:
      return x.boolVal == y.boolVal
    of crDataString:
      return x.stringVal == y.stringVal
    of crDataNumber:
      return x.numberVal == y.numberVal
    of crDataKeyword:
      return x.keywordVal == y.keywordVal
    of crDataFn:
      return x.fnVal == y.fnVal
    of crDataMacro:
      return x.macroVal == y.macroVal
    of crDataSyntax:
      return x.syntaxVal == y.syntaxVal

    of crDataList:
      if x.listVal.len != y.listVal.len:
        return false

      for idx, xi in x.listVal:
        if xi != y.listVal.get(idx):
          return false
      return true

    of crDataSet:
      if x.setVal.len != y.setVal.len:
        return false

      for xi in x.setVal.items:
        if not y.setVal.contains(xi):
          return false
      return true

    of crDataMap:
      if x.mapVal.len != y.mapVal.len:
        return false

      for k, v in x.mapVal.pairs:
        if not (y.mapVal.contains(k) and y.mapVal[k].get == v):
          return false

      return true

    of crDataSymbol:
      # TODO, ns not compared, not decided
      return x.symbolVal == y.symbolVal

    of crDataRecur:
      return x.args == y.args


proc isNumber*(x: CirruData): bool = x.kind == crDataNumber
proc isList*(x: CirruData): bool = x.kind == crDataList
proc isSymbol*(x: CirruData): bool =  x.kind == crDataSymbol
proc isMap*(x: CirruData): bool =  x.kind == crDataMap
proc isString*(x: CirruData): bool = x.kind == crDataString
proc isKeyword*(x: CirruData): bool = x.kind == crDataKeyword
proc isNil*(x: CirruData): bool = x.kind == crDataNil
proc isSet*(x: CirruData): bool = x.kind == crDataSet
proc isFn*(x: CirruData): bool = x.kind == crDataFn
proc isBool*(x: CirruData): bool = x.kind == crDataBool
proc isMacro*(x: CirruData): bool = x.kind == crDataMacro
proc isSyntax*(x: CirruData): bool = x.kind == crDataSyntax
proc isRecur*(x: CirruData): bool = x.kind == crDataRecur

proc `!=`*(x, y: CirruData): bool =
  not (x == y)

iterator items*(x: CirruData): CirruData =
  case x.kind:
  of crDataList:
    for i, child in x.listVal:
      yield child

  of crDataSet:
    for child in x.setVal.items:
      yield child

  else:
    raise newException(EdnOpError, "data is not iterable as a sequence")

iterator pairs*(x: CirruData): tuple[k: CirruData, v: CirruData] =
  case x.kind:
  of crDataList:
    for i, child in x.listVal:
      yield (CirruData(kind: crDataNumber, numberVal: i.float), child)

  of crDataMap:
    for k, v in x.mapVal:
      yield (k, v)

  else:
    raise newException(EdnOpError, "data is not iterable as a sequence by pair")

proc map*[T](xs: CirruData, f: proc (x: CirruData): T): seq[T] =
  case xs.kind:
  of crDataList:
    return xs.listVal.map(f)
  of crDataSet:
    var list = newSeq[CirruData]()
    for x in xs.setVal.items:
      list.add x
    return list.map(f)
  else:
    raise newException(EdnOpError, "map does not work on Cirru EDN literals")

proc mapPairs*[T](xs: CirruData, f: proc (p: tuple[k: CirruData, v: CirruData]): T): seq[T] =
  case xs.kind:
  of crDataMap:
    var ys: seq[tuple[k:CirruData, v:CirruData]] = @[]
    for k, v in xs.mapVal:
      ys.add (k, v)
    return ys.map(f)

  else:
    raise newException(EdnOpError, "map does not work on Cirru EDN literals")

proc contains*(x: CirruData, k: CirruData): bool =
  if x.kind != crDataMap:
    raise newException(EdnOpError, "hasKey only works for a map")
  return x.mapVal.contains(k)

proc get*(x: CirruData, k: CirruData): CirruData =
  case x.kind:
  of crDataMap:
    if x.contains(k):
      return x.mapVal[k].get
    else:
      return CirruData(kind: crDataNil)
  else:
    raise newException(EdnOpError, "can't run get on a literal or seq")

proc toJson*(x: CirruData): JsonNode =
  case x.kind:
  of crDataNil:
    return JsonNode(kind: JNull)
  of crDataBool:
    return JsonNode(kind: JBool, bval: x.boolVal)
  of crDataNumber:
    return JsonNode(kind: JFloat, fnum: x.numberVal)
  of crDataString:
    return JsonNode(kind: JString, str: x.stringVal)
  of crDataKeyword:
    return JsonNode(kind: JString, str: x.keywordVal)
  of crDataList:
    var elems: seq[JsonNode] = @[]
    for i, child in x.listVal:
      elems.add toJson(child)
    return JsonNode(kind: JArray, elems: elems)
  of crDataSet:
    var elems: seq[JsonNode] = @[]
    for child in x.setVal.items:
      elems.add toJson(child)
    return JsonNode(kind: JArray, elems: elems)
  of crDataMap:
    var fields: OrderedTable[string, JsonNode]
    for k, v in x.mapVal.pairs():
      case k.kind:
      of crDataString:
        fields[k.stringVal] = toJson(v)
      of crDataKeyword:
        fields[k.keywordVal] = toJson(v)
      else:
        raise newException(EdnOpError, "required string keys in JObject")
    return JsonNode(kind: JObject, fields: fields)

  of crDataSymbol:
    return JsonNode(kind: JString, str: x.symbolVal)

  of crDataFn: return JsonNode(kind: JNull)
  of crDataMacro: return JsonNode(kind: JNull)
  of crDataSyntax: return JsonNode(kind: JNull)
  of crDataRecur: return JsonNode(kind: JNull)

# notice that JSON does not have keywords or some other types
proc toCirruData*(v: JsonNode): CirruData =
  case v.kind
  of JString:
    return CirruData(kind: crDataString, stringVal: v.str)
  of JInt:
    return CirruData(kind: crDataNumber, numberVal: v.to(float))
  of JFloat:
    return CirruData(kind: crDataNumber, numberVal: v.fnum)
  of JBool:
    return CirruData(kind: crDataBool, boolVal: v.bval)
  of JNull:
    return CirruData(kind: crDataNil)
  of JArray:
    var arr = initTernaryTreeList[CirruData](@[])
    for v in v.elems:
      arr = arr.append toCirruData(v)
    return CirruData(kind: crDataList, listVal: arr)
  of JObject:
    var table = initTable[CirruData, CirruData]()
    for key, value in v:
      let keyContent = CirruData(kind: crDataString, stringVal: key)
      let value = toCirruData(value)
      table.add(keyContent, value)
    return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(table))

proc `[]`*(xs: CirruData, idx: int): CirruData =
  case xs.kind:
  of crDataList:
    xs.listVal.get(idx)
  else:
    raise newException(ValueError, "Cannot index on cirru string")

proc len*(xs: CirruData): int =
  case xs.kind:
  of crDataList:
    return xs.listVal.len
  of crDataString:
    return xs.stringVal.len
  of crDataMap:
    return xs.mapVal.len
  of crDataNil:
    return 0
  else:
    coloredEcho(fgRed, $xs)
    raiseEvalError("Data has no len function", xs)

proc `[]`*(xs: CirruData, fromTo: HSlice[int, int]): seq[CirruData] =
  if xs.kind != crDataList:
    raise newException(ValueError, "Cannot create iterator, it is not a list")

  let fromA = fromTo.a
  let toB = fromTo.b
  let size = toB - fromA + 1
  newSeq(result, size)
  for idx in 0..<size:
    result[idx] = xs[fromA + idx]

proc `[]`*(xs: CirruData, fromTo: HSlice[int, BackwardsIndex]): seq[CirruData] =
  if xs.kind != crDataList:
    raiseEvalError("Cannot create iterator on data", xs)

  let fromA = fromTo.a
  let toB =  xs.len - fromTo.b.int
  xs[fromA .. toB]

proc parseLiteral*(token: string, ns: string, scope: Option[CirruDataScope]): CirruData =
  if token == "":
    raise newException(ValueError, "Unknown empty symbol")

  if (token.len > 0) and (token[0] == '|' or token[0] == '"'):
    return CirruData(kind: crDataString, stringVal: token[1..^1])
  elif token[0] == ':':
    return CirruData(kind: crDataKeyword, keywordVal: token[1..^1])
  elif token[0] == '\'':
    return CirruData(kind: crDataSymbol, symbolVal: token[1..^1])

  elif match(token, re"-?\d+(\.\d+)?"):
    return CirruData(kind: crDataNumber, numberVal: parseFloat(token))
  elif token == "true":
    return CirruData(kind: crDataBool, boolVal: true)
  elif token == "false":
    return CirruData(kind: crDataBool, boolVal: false)
  elif token == "nil":
    return CirruData(kind: crDataNil)
  elif token == "&PI":
    return CirruData(kind: crDataNumber, numberVal: PI)
  elif token == "&E":
    return CirruData(kind: crDataNumber, numberVal: E)
  else:
    CirruData(kind: crDataSymbol, symbolVal: token, ns: ns, scope: scope)

proc toCirruData*(xs: CirruNode, ns: string, scope: Option[CirruDataScope]): CirruData =
  if xs.kind == cirruString:
    parseLiteral(xs.text, ns, scope)
  else:
    var list = initTernaryTreeList[CirruData](@[])
    for x in xs:
      list = list.append x.toCirruData(ns, scope)
    CirruData(kind: crDataList, listVal: list)

proc toCirruData*(xs: CirruEdnValue, ns: string, scope: Option[CirruDataScope]): CirruData =
  case xs.kind
  of crEdnNil: CirruData(kind: crDataNil)
  of crEdnBool: CirruData(kind: crDataBool, boolVal: xs.boolVal)
  of crEdnNumber: CirruData(kind: crDataNumber, numberVal: xs.numberVal)
  of crEdnString: CirruData(kind: crDataString, stringVal: xs.stringVal)
  of crEdnKeyword: CirruData(kind: crDataKeyword, keywordVal: xs.keywordVal)
  of crEdnVector:
    var ys = initTernaryTreeList[CirruData](@[])
    for item in xs.listVal:
      ys = ys.append item.toCirruData(ns, scope)
    CirruData(kind: crDataList, listVal: ys)
  of crEdnList:
    var ys = initTernaryTreeList[CirruData](@[])
    for item in xs.listVal:
      ys = ys.append item.toCirruData(ns, scope)
    CirruData(kind: crDataList, listVal: ys)
  of crEdnSet:
    var ys: seq[CirruData] = @[]
    for item in xs.listVal:
      ys.add item.toCirruData(ns, scope)
    CirruData(kind: crDataSet, setVal: toHashSet(ys))
  of crEdnMap:
    var ys: Table[CirruData, CirruData]
    for key, value in xs.mapVal:
      ys[key.toCirruData(ns, scope)] = value.toCirruData(ns, scope)
    CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(ys))
  of crEdnQuotedCirru: xs.quotedVal.toCirruData(ns, scope)

proc toCirruCode*(v: JsonNode, ns: string): CirruData =
  case v.kind
  of JBool:
    return CirruData(kind: crDataBool, boolVal: v.bval)
  of JString:
    return parseLiteral(v.str, ns, none(CirruDataScope))
  of JInt:
    return CirruData(kind: crDataNumber, numberVal: v.num.float)
  of JFloat:
    return CirruData(kind: crDataNumber, numberVal: v.fnum)
  of JArray:
    let arr = v.elems.map(proc(item: JsonNode): CirruData =
      item.toCirruCode(ns)
    )
    return CirruData(kind: crDataList, listVal: initTernaryTreeList(arr))
  else:
    echo "Unexpected type: ", v
    raise newException(ValueError, "Cannot generate code from JSON based on unexpected type")

proc checkExprStructure*(exprList: CirruData): bool =
  case exprList.kind
  of crDataSymbol: return true
  of crDataNumber: return true
  of crDataBool: return true
  of crDataNil: return true
  of crDataString: return true
  of crDataKeyword: return true
  of crDataList:
    for item in exprList:
      if not checkExprStructure(item):
        return false
    return true
  else:
    return false

proc fakeNativeCode*(info: string): RefCirruData =
  RefCirruData(kind: crDataList, listVal: initTernaryTreeList(@[
    CirruData(kind: crDataSymbol, symbolVal: "defnative", ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: info, ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: "__native_code__", ns: coreNs)
  ]))

proc spreadArgs*(xs: seq[CirruData]): seq[CirruData] =
  var args: seq[CirruData]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      if x.isList.not:
        raiseEvalError("Spread mode expects a list", xs)
      for y in x:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&":
      spreadMode = true
    else:
      args.add x
  args

proc spreadFuncArgs*(xs: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): seq[CirruData] =
  var args: seq[CirruData] = @[]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      let ys = interpret(x, scope)
      if not ys.isList:
        raiseEvalError("Spread mode expects a list", xs)
      for y in ys:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&":
      spreadMode = true
    else:
      args.add interpret(x, scope)
  args
