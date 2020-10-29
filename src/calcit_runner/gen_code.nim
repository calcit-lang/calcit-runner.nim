
import macros
import strformat
import options
import json
import sequtils

import ternary_tree

import ./types
import ./data
import ./errors

proc toCirruData(x: string, ns: string): CirruData =
  return parseLiteral(x, ns, none(CirruDataScope))

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
    return parseLiteral(v.str, ns, none(CirruDataScope))
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

proc fakeNativeCode*(info: string): RefCirruData =
  RefCirruData(kind: crDataList, listVal: initTernaryTreeList(@[
    CirruData(kind: crDataSymbol, symbolVal: "defnative", ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: info, ns: coreNs),
    CirruData(kind: crDataSymbol, symbolVal: "__native_code__", ns: coreNs)
  ]))

proc shortenCode*(code: string, n: int): string =
  if code.len > n:
    code[0..<n] & "..."
  else:
    code


proc processArguments*(definedArgs: TernaryTreeList[CirruData], passedArgs: seq[CirruData]): CirruDataScope =
  var argsScope: CirruDataScope

  let splitPosition = definedArgs.findIndex(proc(item: CirruData): bool =
    item.kind == crDataSymbol and item.symbolVal == "&"
  )

  if splitPosition >= 0:
    if passedArgs.len < splitPosition:
      raiseEvalError("No enough arguments", CirruData(kind: crDataList, listVal: definedArgs))
    if splitPosition != (definedArgs.len - 2):
      raiseEvalError("& should appear before last argument", CirruData(kind: crDataList, listVal: definedArgs))
    for idx in 0..<splitPosition:
      let definedArgName = definedArgs[idx]
      if definedArgName.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", definedArgName)
      argsScope = argsScope.assoc(definedArgName.symbolVal, passedArgs[idx])
    var varList = initTernaryTreeList[CirruData](@[])
    for idx in splitPosition..<passedArgs.len:
      varList = varList.append passedArgs[idx]
    let varArgName = definedArgs[definedArgs.len - 1]
    if varArgName.kind != crDataSymbol:
      raiseEvalError("Expected var arg in symbol", varArgName)
    argsScope = argsScope.assoc(varArgName.symbolVal, CirruData(kind: crDataList, listVal: varList))
    return argsScope

  else:
    var counter = 0
    if definedArgs.len != passedArgs.len:
      raiseEvalError(fmt"Args length mismatch, defined:{definedArgs.len} passed:{passedArgs.len}", CirruData(kind: crDataList, listVal: definedArgs))
    definedArgs.each(proc(arg: CirruData): void =
      if arg.kind != crDataSymbol:
        raiseEvalError("Expects arg in symbol", arg)
      argsScope = argsScope.assoc(arg.symbolVal, passedArgs[counter])
      counter += 1
    )
    return argsScope
