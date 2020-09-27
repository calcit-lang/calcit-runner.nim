
import tables
import sets
import options

import ternary_tree

import ./types

proc crData*(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc crData*(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc crData*(x: bool): CirruData =
  CirruData(kind: crDataBool, boolVal: x)

proc crData*(x: string, target: string = "string"): CirruData =
  case target:
  of "keyword":
    CirruData(kind: crDataKeyword, keywordVal: x)
  of "symbol":
    CirruData(kind: crDataSymbol, symbolVal: x, ns: "user", scope: none(CirruDataScope))
  of "string":
    CirruData(kind: crDataString, stringVal: x)
  else:
    echo "[crData warn] Unknown kind target passed to crData"
    CirruData(kind: crDataString, stringVal: x)

proc crData*(): CirruData =
  CirruData(kind: crDataNil)

proc crData*(xs: seq[CirruData], asList: bool = false): CirruData =
  CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))

proc crData*(xs: HashSet[CirruData]): CirruData =
  CirruData(kind: crDataSet, setVal: xs)

proc crData*(xs: Table[CirruData, CirruData]): CirruData =
  CirruData(kind: crDataMap, mapVal: xs)
