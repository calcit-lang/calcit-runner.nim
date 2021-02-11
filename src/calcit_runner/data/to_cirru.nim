
import lists

import cirru_parser
import ternary_tree

import ../types
import ../data
import ../data/virtual_list
import ../util/errors

proc toCirruNode*(x: CirruData): CirruNode =
  case x.kind
  of crDataNil:
    return CirruNode(kind: cirruToken, token: "nil")
  of crDataBool:
    return CirruNode(kind: cirruToken, token: $x.boolVal)
  of crDataNumber:
    return CirruNode(kind: cirruToken, token: $x.numberVal)
  of crDataString:
    return CirruNode(kind: cirruToken, token: "|" & x.stringVal)
  of crDataKeyword:
    return CirruNode(kind: cirruToken, token: ":" & x.keywordVal)
  of crDataList:
    var elems: DoublyLinkedList[CirruNode]
    for child in x.listVal:
      elems.append toCirruNode(child)
    return CirruNode(kind: cirruList, list: elems)

  of crDataSymbol:
    # not implement symbol in cirru-edn
    return CirruNode(kind: cirruToken, token: x.symbolVal)
  of crDataTernary:
    return CirruNode(kind: cirruToken, token: $x.ternaryVal)

  of crDataSet, crDataMap, crDataFn, crDataProc, crDataMacro, crDataSyntax, crDataRecur, crDataAtom:
    raiseEvalError("Unexpect set to convert to CirruNode: ", x)
  of crDataThunk:
    raiseEvalError("must calculate thunk before converting", x)

proc nodesToCirruData*(xs: CirruNode, ns: string): CirruData =
  if xs.kind == cirruToken:
    parseLiteral(xs.token, ns)
  else:
    var list = initCrVirtualList[CirruData](@[])
    for x in xs:
      list = list.append x.nodesToCirruData(ns)
    CirruData(kind: crDataList, listVal: list)

# nodes using bare string
proc toCirruNodesData*(xs: CirruNode): CirruData =
  if xs.kind == cirruToken:
    CirruData(kind: crDataString, stringVal: xs.token)
  else:
    var list = initCrVirtualList[CirruData](@[])
    for x in xs:
      list = list.append x.toCirruNodesData()
    CirruData(kind: crDataList, listVal: list)
