
import json
import sets
import tables

import ternary_tree
import dual_balanced_ternary
import cirru_edn
import cirru_parser

import ../types
import ../util/errors

proc toJson*(x: CirruData, keywordColon: bool = false): JsonNode =
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
    if keywordColon:
      return JsonNode(kind: JString, str: ":" & x.keywordVal)
    else:
      return JsonNode(kind: JString, str: x.keywordVal)
  of crDataList:
    var elems: seq[JsonNode] = @[]
    for i, child in x.listVal:
      elems.add toJson(child, keywordColon)
    return JsonNode(kind: JArray, elems: elems)
  of crDataSet:
    var elems: seq[JsonNode] = @[]
    for child in x.setVal.items:
      elems.add toJson(child, keywordColon)
    return JsonNode(kind: JArray, elems: elems)
  of crDataMap:
    var fields: OrderedTable[string, JsonNode]
    for k, v in x.mapVal:
      case k.kind:
      of crDataString:
        fields[k.stringVal] = toJson(v, keywordColon)
      of crDataKeyword:
        if keywordColon:
          fields[":" & k.keywordVal] = toJson(v, keywordColon)
        else:
          fields[k.keywordVal] = toJson(v, keywordColon)
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
  of crDataAtom: return JsonNode(kind: JNull)
  of crDataTernary: return JsonNode(kind: JString, str: $x.ternaryVal)
  of crDataThunk:
    raiseEvalError("must calculate thunk before to json", x)

# notice that JSON does not have keywords or some other types
proc jsonToCirruData*(v: JsonNode): CirruData =
  case v.kind
  of JString:
    if v.str.len > 0 and v.str[0] == ':':
      return CirruData(kind: crDataKeyword, keywordVal: loadKeyword(v.str[1..^1]))
    else:
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
      arr = arr.append jsonToCirruData(v)
    return CirruData(kind: crDataList, listVal: arr)
  of JObject:
    var table = initTable[CirruData, CirruData]()
    for key, value in v:
      let keyContent =
        if key.len > 0 and key[0] == ':':
          CirruData(kind: crDataKeyword, keywordVal: loadKeyword(key[1..^1]))
        else:
          CirruData(kind: crDataString, stringVal: key)
      let value = jsonToCirruData(value)
      table[keyContent] = value
    return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(table))
