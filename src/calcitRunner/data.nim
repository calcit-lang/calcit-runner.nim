import tables
import hashes
import sets
import options

import cirruParser

import sequtils
import sets
import tables
import json

import cirruParser
import ./types

proc hash*(value: CirruNode): Hash =
  case value.kind:
  of cirruString:
    return hash(value.text)
  of cirruSeq:
    result = hash("cirruSeq:")
    for x in value:
      result = result !& hash(x)
    result = !$ result

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
    of crDataVector:
      result = hash("vector:")
      for idx, x in value.vectorVal:
        result = result !& hash(x)
      result = !$ result
    of crDataList:
      result = hash("list:")
      for idx, x in value.listVal:
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

    of crDataQuotedCirru:
      result =  hash("quoted:")
      result = result !& hash(value.quotedVal)
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

    of crDataVector:
      if x.vectorVal.len != y.vectorVal.len:
        return false
      for idx, xi in x.vectorVal:
        if xi != y.vectorVal[idx]:
          return false
      return true

    of crDataList:
      if x.listVal.len != y.listVal.len:
        return false

      for idx, xi in x.listVal:
        if xi != y.listVal[idx]:
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
        if not (y.mapVal.hasKey(k) and y.mapVal[k] == v):
          return false

      return true

    of crDataQuotedCirru:
      return x.quotedVal == y.quotedVal

proc `!=`*(x, y: CirruData): bool =
  not (x == y)

iterator items*(x: CirruData): CirruData =
  case x.kind:
  of crDataList:
    for i, child in x.listVal:
      yield child

  of crDataVector:
    for i, child in x.vectorVal:
      yield child

  of crDataSet:
    for child in x.setVal.items:
      yield child

  else:
    raise newException(EdnOpError, "data is not iterable as a sequence")

iterator pairs*(x: CirruData): tuple[k: CirruData, v: CirruData] =
  if x.kind != crDataMap:
    raise newException(EdnOpError, "data is not iterable as map")

  for k, v in x.mapVal:
    yield (k, v)



proc map*[T](xs: CirruData, f: proc (x: CirruData): T): seq[T] =
  case xs.kind:
  of crDataList:
    return xs.listVal.map(f)
  of crDataVector:
    return xs.vectorVal.map(f)
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
  return x.mapVal.hasKey(k)

proc get*(x: CirruData, k: CirruData): CirruData =
  case x.kind:
  of crDataMap:
    if x.contains(k):
      return x.mapVal[k]
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
  of crDataVector:
    var elems: seq[JsonNode] = @[]
    for i, child in x.vectorVal:
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

  of crDataFn:
    return JsonNode(kind: JNull)

  of crDataQuotedCirru:
    return toJson(x.quotedVal)

# notice that JSON does not have keywords or some other types
proc toCirruEdn*(v: JsonNode): CirruData =
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
    var arr: seq[CirruData]
    for v in v.elems:
      arr.add toCirruEdn(v)
    return CirruData(kind: crDataVector, vectorVal: arr)
  of JObject:
    var table = initTable[CirruData, CirruData]()
    for key, value in v:
      let keyContent = CirruData(kind: crDataString, stringVal: key)
      let value = toCirruEdn(value)
      table.add(keyContent, value)
    return CirruData(kind: crDataMap, mapVal: table)
