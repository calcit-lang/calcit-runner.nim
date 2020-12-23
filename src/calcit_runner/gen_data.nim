
import tables
import sets
import options
import strformat

import ternary_tree
import cirru_edn

import ./types
import ./data

proc crData*(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc crData*(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc crData*(x: bool): CirruData =
  CirruData(kind: crDataBool, boolVal: x)

proc crData*(x: string, target: string = "string"): CirruData =
  case target:
  of "keyword":
    CirruData(kind: crDataKeyword, keywordVal: loadKeyword(x))
  of "symbol":
    CirruData(kind: crDataSymbol, symbolVal: x, ns: "user")
  of "string":
    CirruData(kind: crDataString, stringVal: x)
  else:
    echo fmt"[crData warn] Unknown kind target passed to crData: {target}"
    CirruData(kind: crDataString, stringVal: x)

proc crData*(): CirruData =
  CirruData(kind: crDataNil)

proc crData*(xs: seq[CirruData]): CirruData =
  CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))

proc crData*(xs: HashSet[CirruData]): CirruData =
  CirruData(kind: crDataSet, setVal: xs)

proc crData*(xs: Table[CirruData, CirruData]): CirruData =
  CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(xs))

proc toCirruData*(xs: CirruEdnValue, ns: string, scope: Option[CirruDataScope]): CirruData =
  case xs.kind
  of crEdnNil: CirruData(kind: crDataNil)
  of crEdnBool: CirruData(kind: crDataBool, boolVal: xs.boolVal)
  of crEdnNumber: CirruData(kind: crDataNumber, numberVal: xs.numberVal)
  of crEdnString: CirruData(kind: crDataString, stringVal: xs.stringVal)
  of crEdnKeyword: CirruData(kind: crDataKeyword, keywordVal: loadKeyword(xs.keywordVal))
  of crEdnVector:
    var ys = initTernaryTreeList[CirruData](@[])
    for item in xs.vectorVal:
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
  of crEdnQuotedCirru: xs.quotedVal.toCirruData(ns)
