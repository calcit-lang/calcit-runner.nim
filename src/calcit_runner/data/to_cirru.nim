
import lists

import cirru_parser
import ternary_tree

import ../types
import ../data
import ../util/errors

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
    return CirruNode(kind: cirruString, text: ":" & x.keywordVal)
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

proc nodesToCirruData*(xs: CirruNode, ns: string): CirruData =
  if xs.kind == cirruString:
    parseLiteral(xs.text, ns)
  else:
    var list = initTernaryTreeList[CirruData](@[])
    for x in xs:
      list = list.append x.nodesToCirruData(ns)
    CirruData(kind: crDataList, listVal: list)

# nodes using bare string
proc toCirruNodesData*(xs: CirruNode): CirruData =
  if xs.kind == cirruString:
    CirruData(kind: crDataString, stringVal: xs.text)
  else:
    var list = initTernaryTreeList[CirruData](@[])
    for x in xs:
      list = list.append x.toCirruNodesData()
    CirruData(kind: crDataList, listVal: list)
