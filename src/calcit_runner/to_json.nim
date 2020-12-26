
import json
import lists
import sets
import tables

import ternary_tree
import dual_balanced_ternary
import cirru_edn
import cirru_parser

import ./types
import ./errors

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
      return JsonNode(kind: JString, str: ":" & x.keywordVal[])
    else:
      return JsonNode(kind: JString, str: x.keywordVal[])
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
          fields[":" & k.keywordVal[]] = toJson(v, keywordColon)
        else:
          fields[k.keywordVal[]] = toJson(v, keywordColon)
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
proc toCirruData*(v: JsonNode): CirruData =
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
      arr = arr.append toCirruData(v)
    return CirruData(kind: crDataList, listVal: arr)
  of JObject:
    var table = initTable[CirruData, CirruData]()
    for key, value in v:
      let keyContent =
        if key.len > 0 and key[0] == ':':
          CirruData(kind: crDataKeyword, keywordVal: loadKeyword(key[1..^1]))
        else:
          CirruData(kind: crDataString, stringVal: key)
      let value = toCirruData(value)
      table[keyContent] = value
    return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(table))

proc toCirruNode*(x: CirruData): CirruNode =
  case x.kind
  of crDataNil:
    return CirruNode(kind: cirruString, text: "nil")
  of crDataBool:
    return CirruNode(kind: cirruString, text: $x.boolVal)
  of crDataNumber:
    return CirruNode(kind: cirruString, text: $x.numberVal)
  of crDataString:
    return CirruNode(kind: cirruString, text: "|" & x.stringVal)
  of crDataKeyword:
    return CirruNode(kind: cirruString, text: ":" & x.keywordVal[])
  of crDataList:
    var elems: DoublyLinkedList[CirruNode]
    for child in x.listVal:
      elems.append toCirruNode(child)
    return CirruNode(kind: cirruSeq, list: elems)

  of crDataSymbol:
    # not implement symbol in cirru-edn
    return CirruNode(kind: cirruString, text: x.symbolVal)
  of crDataTernary:
    return CirruNode(kind: cirruString, text: $x.ternaryVal)

  of crDataSet, crDataMap, crDataFn, crDataProc, crDataMacro, crDataSyntax, crDataRecur, crDataAtom:
    raiseEvalError("Unexpect set to convert to CirruNode: ", x)
  of crDataThunk:
    raiseEvalError("must calculate thunk before converting", x)

proc toEdn*(x: CirruData): CirruEdnValue =
  case x.kind:
  of crDataNil:
    return CirruEdnValue(kind: crEdnNil)
  of crDataBool:
    return CirruEdnValue(kind: crEdnBool, boolVal: x.boolVal)
  of crDataNumber:
    return CirruEdnValue(kind: crEdnNumber, numberVal: x.numberVal)
  of crDataString:
    return CirruEdnValue(kind: crEdnString, stringVal: x.stringVal)
  of crDataKeyword:
    return CirruEdnValue(kind: crEdnKeyword, keywordVal: x.keywordVal[])
  of crDataList:
    var elems: seq[CirruEdnValue] = @[]
    for i, child in x.listVal:
      elems.add toEdn(child)
    return CirruEdnValue(kind: crEdnVector, vectorVal: elems)
  of crDataSet:
    var elems: HashSet[CirruEdnValue]
    for child in x.setVal.items:
      elems.incl toEdn(child)
    return CirruEdnValue(kind: crEdnSet, setVal: elems)
  of crDataMap:
    var fields: Table[CirruEdnValue, CirruEdnValue]
    for k, v in x.mapVal:
      fields[toEdn(k)] = toEdn(v)
    return CirruEdnValue(kind: crEdnMap, mapVal: fields)

  of crDataSymbol:
    # not implement symbol in cirru-edn
    return CirruEdnValue(kind: crEdnString, stringVal: x.symbolVal)

  of crDataTernary: return CirruEdnValue(kind: crEdnString, stringVal: $x.ternaryVal)

  of crDataProc, crDataFn, crDataMacro, crDataSyntax, crDataRecur, crDataAtom:
    return CirruEdnValue(kind: crEdnString, stringVal: "<<" & $x.kind & ">>\n" & $x)

  of crDataThunk:
    raiseEvalError("must calculate thunk before converting", x)
