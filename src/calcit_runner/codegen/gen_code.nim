
import json
import sequtils

import ternary_tree

import ../types
import ../data
import ../data/virtual_list

var genSymIndex* = 0

proc genCirruData(x: string, ns: string): CirruData =
  return parseLiteral(x, ns)

proc genCirruData(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc genCirruData(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc genCirruData(xs: varargs[CirruData]): CirruData =
  var args: seq[CirruData]
  for x in xs:
    args.add x
  CirruData(kind: crDataList, listVal: initCrVirtualList(args))

proc toCirruCode*(v: JsonNode, ns: string): CirruData =
  case v.kind
  of JBool:
    return CirruData(kind: crDataBool, boolVal: v.bval)
  of JString:
    return parseLiteral(v.str, ns)
  of JInt:
    return CirruData(kind: crDataNumber, numberVal: v.num.float)
  of JFloat:
    return CirruData(kind: crDataNumber, numberVal: v.fnum)
  of JArray:
    let arr = v.elems.map(proc(item: JsonNode): CirruData =
      item.toCirruCode(ns)
    )
    return CirruData(kind: crDataList, listVal: initCrVirtualList(arr))
  else:
    echo "Unexpected type: ", v
    raise newException(ValueError, "Cannot generate code from JSON based on unexpected type")

proc shortenCode*(code: string, n: int): string =
  if code.len > n:
    code[0..<n] & "..."
  else:
    code

proc generateMainCode*(code: CirruData, ns: string): CirruData =
  CirruData(kind: crDataList, listVal: initCrVirtualList(@[
    CirruData(kind: crDataSymbol, symbolVal: "defn", ns: ns),
    CirruData(kind: crDataSymbol, symbolVal: "main!", ns: ns),
    CirruData(kind: crDataList, listVal: initCrVirtualList[CirruData](@[])),
    CirruData(kind: crDataList, listVal: initCrVirtualList(@[
      CirruData(kind: crDataSymbol, symbolVal: "echo", ns: ns),
      code,
    ])),
  ]))
