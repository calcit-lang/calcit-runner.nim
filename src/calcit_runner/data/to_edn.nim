
import sets
import tables
import options

import cirru_edn
import ternary_tree

import ../types
import ../util/errors
import ../data/virtual_list

import ./to_cirru

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
    return CirruEdnValue(kind: crEdnKeyword, keywordVal: x.keywordVal)
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

  of crDataRecord:
    var values: seq[CirruEdnValue]
    for v in x.recordValues:
      values.add toEdn(v)
    return CirruEdnValue(
      kind: crEdnRecord, recordName: x.recordName,
      recordFields: x.recordFields, recordValues: values
    )

  of crDataSymbol:
    # not implement symbol in cirru-edn
    return CirruEdnValue(kind: crEdnString, stringVal: x.symbolVal)

  of crDataTernary: return CirruEdnValue(kind: crEdnString, stringVal: $x.ternaryVal)

  of crDataProc, crDataFn, crDataMacro, crDataSyntax, crDataRecur, crDataAtom:
    return CirruEdnValue(kind: crEdnString, stringVal: "<<" & $x.kind & ">>\n" & $x)

  of crDataThunk:
    raiseEvalError("must calculate thunk before converting", x)

proc ednToCirruData*(xs: CirruEdnValue, ns: string, scope: Option[CirruDataScope]): CirruData =
  case xs.kind
  of crEdnNil: CirruData(kind: crDataNil)
  of crEdnBool: CirruData(kind: crDataBool, boolVal: xs.boolVal)
  of crEdnNumber: CirruData(kind: crDataNumber, numberVal: xs.numberVal)
  of crEdnString: CirruData(kind: crDataString, stringVal: xs.stringVal)
  of crEdnKeyword: CirruData(kind: crDataKeyword, keywordVal: loadKeyword(xs.keywordVal))
  of crEdnVector:
    var ys = initCrVirtualList[CirruData](@[])
    for item in xs.vectorVal:
      ys = ys.append item.ednToCirruData(ns, scope)
    CirruData(kind: crDataList, listVal: ys)
  of crEdnList:
    var ys = initCrVirtualList[CirruData](@[])
    for item in xs.listVal:
      ys = ys.append item.ednToCirruData(ns, scope)
    CirruData(kind: crDataList, listVal: ys)
  of crEdnSet:
    var ys: seq[CirruData] = @[]
    for item in xs.setVal:
      ys.add item.ednToCirruData(ns, scope)
    CirruData(kind: crDataSet, setVal: toHashSet(ys))
  of crEdnMap:
    var ys: Table[CirruData, CirruData]
    for key, value in xs.mapVal:
      ys[key.ednToCirruData(ns, scope)] = value.ednToCirruData(ns, scope)
    CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(ys))
  of crEdnRecord:
    for idx, field in xs.recordFields:
      if idx == 0:
        continue
      if field <= xs.recordFields[idx-1]:
        raiseEvalError("Invalid order from EDN data", CirruData(kind: crDataString, stringVal: field))

    var values: seq[CirruData]
    for v in xs.recordValues:
      values.add(v.ednToCirruData(ns, scope))
    CirruData(
      kind: crDataRecord, recordName: xs.recordName,
      recordFields: xs.recordFields, recordValues: values,
    )

  of crEdnQuotedCirru: xs.quotedVal.nodesToCirruData(ns)

proc getKwd*(x: CirruEdnValue, k: string): CirruEdnValue =
  if x.kind != crEdnMap:
    raise newException(ValueError, "getKwd expects a map")
  x.get(genCrEdnKeyword(k))

proc containsKwd*(x: CirruEdnValue, k: string): bool =
  if x.kind != crEdnMap:
    raise newException(ValueError, "containsKwd expects a map")
  x.contains(genCrEdnKeyword(k))
