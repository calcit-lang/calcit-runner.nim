
import macros
import strformat
import json
import sequtils

import ternary_tree

import ./types
import ./data

var genSymIndex* = 0

proc toCirruData(x: string, ns: string): CirruData =
  return parseLiteral(x, ns)

proc toCirruData(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc toCirruData(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc toCirruData(xs: varargs[CirruData]): CirruData =
  var args: seq[CirruData]
  for x in xs:
    args.add x
  CirruData(kind: crDataList, listVal: initTernaryTreeList(args))

macro genCirru*(code: untyped, ns: untyped): CirruData =
  # echo code.treeRepr
  case code.kind
  of nnkNilLit:
    return newCall(bindSym"toCirruData", newLit("nil"))
  of nnkIntLit:
    return newCall(bindSym"toCirruData", newLit(code.intVal.int))
  of nnkFloatLit:
    return newCall(bindSym"toCirruData", newLit(code.floatVal.float))
  of nnkIdent:
    return newCall(bindSym"toCirruData", newLit(code.strVal), ns)
  of nnkStrLit:
    return newCall(bindSym"toCirruData", newLit(code.strVal), ns)
  of nnkBracket:
    var node = newCall(bindSym"toCirruData")
    for x in code:
      node.add newCall(bindSym"genCirru", x, ns)
      # echo "code: ", x.treeRepr
    return node
  else:
    raise newException(ValueError, fmt"Unknown kind of code {code.kind}, {code.treeRepr}")

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
    return CirruData(kind: crDataList, listVal: initTernaryTreeList(arr))
  else:
    echo "Unexpected type: ", v
    raise newException(ValueError, "Cannot generate code from JSON based on unexpected type")

proc checkExprStructure*(exprList: CirruData): bool =
  case exprList.kind
  of crDataSymbol: return true
  of crDataNumber: return true
  of crDataBool: return true
  of crDataNil: return true
  of crDataString: return true
  of crDataKeyword: return true
  of crDataList:
    for item in exprList:
      if not checkExprStructure(item):
        return false
    return true
  else:
    return false

proc shortenCode*(code: string, n: int): string =
  if code.len > n:
    code[0..<n] & "..."
  else:
    code

proc generateMainCode*(code: CirruData, ns: string): CirruData =
  CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
    CirruData(kind: crDataSymbol, symbolVal: "defn", ns: ns),
    CirruData(kind: crDataSymbol, symbolVal: "main!", ns: ns),
    CirruData(kind: crDataList, listVal: initTernaryTreeList[CirruData](@[])),
    CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      CirruData(kind: crDataSymbol, symbolVal: "echo", ns: ns),
      code,
    ])),
  ]))
