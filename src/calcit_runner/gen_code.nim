
import macros
import strformat

import ternary_tree

import ./types

proc toCirruData(x: string, ns: string): CirruData =
  if x == "true":
    CirruData(kind: crDataBool, boolVal: true)
  elif x == "false":
    CirruData(kind: crDataBool, boolVal: false)
  else:
    CirruData(kind: crDataSymbol, symbolVal: x, ns: ns)

proc toCirruData(x: int): CirruData =
  CirruData(kind: crDataNumber, numberVal: x.float)

proc toCirruData(x: float): CirruData =
  CirruData(kind: crDataNumber, numberVal: x)

proc toCirruNil(): CirruData =
  CirruData(kind: crDataNil)

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
