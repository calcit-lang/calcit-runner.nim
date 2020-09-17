
import tables
import sets

import ./types

proc crEdn*(x: int): CirruData =
  CirruData(kind: crEdnNumber, numberVal: x.float)

proc crEdn*(x: float): CirruData =
  CirruData(kind: crEdnNumber, numberVal: x)

proc crEdn*(x: bool): CirruData =
  CirruData(kind: crEdnBool, boolVal: x)

proc crEdn*(x: string, asKeyword: bool = false): CirruData =
  if asKeyword:
    CirruData(kind: crEdnKeyword, keywordVal: x)
  else:
    CirruData(kind: crEdnString, stringVal: x)

proc crEdn*(): CirruData =
  CirruData(kind: crEdnNil)

proc crEdn*(xs: seq[CirruData], asList: bool = false): CirruData =
  if asList:
    CirruData(kind: crEdnList, listVal: xs)
  else:
    CirruData(kind: crEdnVector, vectorVal: xs)

proc crEdn*(xs: HashSet[CirruData]): CirruData =
  CirruData(kind: crEdnSet, setVal: xs)

proc crEdn*(xs: Table[CirruData, CirruData]): CirruData =
  CirruData(kind: crEdnMap, mapVal: xs)
