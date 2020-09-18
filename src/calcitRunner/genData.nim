
import tables
import sets

import ./types

proc crData*(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc crData*(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc crData*(x: bool): CirruData =
  CirruData(kind: crDataBool, boolVal: x)

proc crData*(x: string, asKeyword: bool = false): CirruData =
  if asKeyword:
    CirruData(kind: crDataKeyword, keywordVal: x)
  else:
    CirruData(kind: crDataString, stringVal: x)

proc crData*(): CirruData =
  CirruData(kind: crDataNil)

proc crData*(xs: seq[CirruData], asList: bool = false): CirruData =
  if asList:
    CirruData(kind: crDataList, listVal: xs)
  else:
    CirruData(kind: crDataVector, vectorVal: xs)

proc crData*(xs: HashSet[CirruData]): CirruData =
  CirruData(kind: crDataSet, setVal: xs)

proc crData*(xs: Table[CirruData, CirruData]): CirruData =
  CirruData(kind: crDataMap, mapVal: xs)
