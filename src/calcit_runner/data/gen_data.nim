
import tables
import sets
import strformat

import ternary_tree
import cirru_edn

import ../types
import ../data/virtual_list

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
    CirruData(kind: crDataSymbol, symbolVal: x, ns: "&crData") # use a special mark
  of "string":
    CirruData(kind: crDataString, stringVal: x)
  else:
    echo fmt"[crData warn] Unknown kind target passed to crData: {target}"
    CirruData(kind: crDataString, stringVal: x)

proc crData*(): CirruData =
  CirruData(kind: crDataNil)

proc crData*(xs: seq[CirruData]): CirruData =
  CirruData(kind: crDataList, listVal: initCrVirtualList(xs))

proc crData*(xs: HashSet[CirruData]): CirruData =
  CirruData(kind: crDataSet, setVal: xs)

proc crData*(xs: Table[CirruData, CirruData]): CirruData =
  CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(xs))
