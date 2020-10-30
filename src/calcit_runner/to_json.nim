
import json
import sets
import tables

import ternary_tree

import ./types

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
    return JsonNode(kind: JString, str: x.keywordVal[])
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
    for k, v in x.mapVal:
      case k.kind:
      of crDataString:
        fields[k.stringVal] = toJson(v)
      of crDataKeyword:
        fields[k.keywordVal[]] = toJson(v)
      else:
        raise newException(ValueError, "required string keys in JObject")
    return JsonNode(kind: JObject, fields: fields)

  of crDataSymbol:
    return JsonNode(kind: JString, str: x.symbolVal)

  of crDataProc: return JsonNode(kind: JNull)
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
      table[keyContent] = value
    return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(table))