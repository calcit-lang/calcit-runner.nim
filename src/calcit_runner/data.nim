import tables
import sets
import options
import system
import sequtils
import math
import strutils
import json
import strformat

import cirru_parser
import cirru_edn
import ternary_tree
import dual_balanced_ternary

import ./types
import ./errors
import ./str_util

proc isNumber*(x: CirruData): bool = x.kind == crDataNumber
proc isList*(x: CirruData): bool = x.kind == crDataList
proc isSymbol*(x: CirruData): bool = x.kind == crDataSymbol
proc isMap*(x: CirruData): bool = x.kind == crDataMap
proc isString*(x: CirruData): bool = x.kind == crDataString
proc isKeyword*(x: CirruData): bool = x.kind == crDataKeyword
proc isNil*(x: CirruData): bool = x.kind == crDataNil
proc isSet*(x: CirruData): bool = x.kind == crDataSet
proc isFn*(x: CirruData): bool = x.kind == crDataProc
proc isBool*(x: CirruData): bool = x.kind == crDataBool
proc isMacro*(x: CirruData): bool = x.kind == crDataMacro
proc isSyntax*(x: CirruData): bool = x.kind == crDataSyntax
proc isRecur*(x: CirruData): bool = x.kind == crDataRecur

iterator items*(x: CirruData): CirruData =
  case x.kind:
  of crDataList:
    for i, child in x.listVal:
      yield child

  of crDataMap:
    for k, v in x.mapVal:
      yield CirruData(kind: crDataList, listVal: initTernaryTreeList(@[k, v]))

  of crDataSet:
    for child in x.setVal.items:
      yield child

  else:
    raise newException(EdnOpError, "data is not iterable as a sequence")

iterator pairs*(x: CirruData): tuple[k: CirruData, v: CirruData] =
  case x.kind:
  of crDataList:
    for i, child in x.listVal:
      yield (CirruData(kind: crDataNumber, numberVal: i.float), child)

  of crDataMap:
    for k, v in x.mapVal:
      yield (k, v)

  else:
    raise newException(EdnOpError, "data is not iterable as a sequence by pair")

proc map*[T](xs: CirruData, f: proc (x: CirruData): T): seq[T] =
  case xs.kind:
  of crDataList:
    return xs.listVal.map(f)
  of crDataSet:
    var list = newSeq[CirruData](xs.setVal.len)
    for idx, x in xs.setVal.items:
      list[idx] = x
    return list.map(f)
  else:
    raise newException(EdnOpError, "map does not work on Cirru EDN literals")

proc mapPairs*[T](xs: CirruData, f: proc (p: tuple[k: CirruData, v: CirruData]): T): seq[T] =
  case xs.kind:
  of crDataMap:
    var ys: seq[tuple[k:CirruData, v:CirruData]] = @[]
    for k, v in xs.mapVal:
      ys.add (k, v)
    return ys.map(f)

  else:
    raise newException(EdnOpError, "map does not work on Cirru EDN literals")

proc contains*(x: CirruData, k: CirruData): bool =
  if x.kind != crDataMap:
    raise newException(EdnOpError, "hasKey only works for a map")
  return x.mapVal.contains(k)

proc get*(x: CirruData, k: CirruData): CirruData =
  case x.kind:
  of crDataMap:
    if x.contains(k):
      return x.mapVal[k].get
    else:
      return CirruData(kind: crDataNil)
  else:
    raise newException(EdnOpError, "can't run get on a literal or seq")

proc `[]`*(xs: CirruData, idx: int): CirruData =
  case xs.kind:
  of crDataList:
    xs.listVal[idx]
  else:
    raise newException(ValueError, "Cannot index on cirru string")

proc len*(xs: CirruData): int =
  case xs.kind:
  of crDataList:
    return xs.listVal.len
  of crDataString:
    return xs.stringVal.len
  of crDataMap:
    return xs.mapVal.len
  of crDataNil:
    return 0
  else:
    raiseEvalError("Data has no len function", xs)

proc `[]`*(xs: CirruData, fromTo: HSlice[int, int]): seq[CirruData] =
  if xs.kind != crDataList:
    raise newException(ValueError, "Cannot create iterator, it is not a list")

  let fromA = fromTo.a
  let toB = fromTo.b
  let size = toB - fromA + 1
  newSeq(result, size)
  for idx in 0..<size:
    result[idx] = xs[fromA + idx]

proc `[]`*(xs: CirruData, fromTo: HSlice[int, BackwardsIndex]): seq[CirruData] =
  if xs.kind != crDataList:
    raiseEvalError("Cannot create iterator on data", xs)

  let fromA = fromTo.a
  let toB = xs.len - fromTo.b.int
  xs[fromA .. toB]

proc parseLiteral*(token: string, ns: string): CirruData =
  if token == "":
    raise newException(ValueError, "Unknown empty symbol")

  if (token.len > 0) and (token[0] == '|' or token[0] == '"'):
    return CirruData(kind: crDataString, stringVal: token[1..^1])
  elif token[0] == ':':
    return CirruData(kind: crDataKeyword, keywordVal: loadKeyword(token[1..^1]))
  elif token[0] == '\'':
    return CirruData(kind: crDataSymbol, symbolVal: token[1..^1], ns: ns, dynamic: true)
  elif token.startsWith("0x"):
    return CirruData(kind: crDataNumber, numberVal: token.parseHexInt.float)
  elif token.matchesFloat:
    return CirruData(kind: crDataNumber, numberVal: parseFloat(token))
  elif token.matchesTernary:
    return CirruData(kind: crDataTernary, ternaryVal: parseTernary(token))
  elif token == "true":
    return CirruData(kind: crDataBool, boolVal: true)
  elif token == "false":
    return CirruData(kind: crDataBool, boolVal: false)
  elif token == "nil":
    return CirruData(kind: crDataNil)
  elif token == "&PI":
    return CirruData(kind: crDataNumber, numberVal: PI)
  elif token == "&E":
    return CirruData(kind: crDataNumber, numberVal: E)
  elif token == "&newline":
    return CirruData(kind: crDataString, stringVal: "\n")
  elif token == "&tab":
    return CirruData(kind: crDataString, stringVal: "\t")
  elif token.len >= 2 and token[0] == '@' and token[1..^1].matchesSimpleVar():
    # expects @*x-y? expanded as (deref *x-y?)
    return CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      CirruData(kind: crDataSymbol, symbolVal: "deref", ns: ns),
      CirruData(kind: crDataSymbol, symbolVal: token[1..^1], ns: ns),
    ]))
  elif token.len >= 3 and token[0..<2] == "~@" and token[2..^1].matchesSimpleVar():
    # expects ~@x-y? expanded as (~@ x-y?)
    return CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      CirruData(kind: crDataSymbol, symbolVal: "~@", ns: ns),
      CirruData(kind: crDataSymbol, symbolVal: token[2..^1], ns: ns),
    ]))
  elif token.len >= 2 and token[0] == '~' and token[1..^1].matchesSimpleVar():
    # expects ~x-y? expanded as (~ x-y?)
    return CirruData(kind: crDataList, listVal: initTernaryTreeList(@[
      CirruData(kind: crDataSymbol, symbolVal: "~", ns: ns),
      CirruData(kind: crDataSymbol, symbolVal: token[1..^1], ns: ns),
    ]))
  else:
    return CirruData(kind: crDataSymbol, symbolVal: token, ns: ns)

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

proc spreadArgs*(xs: seq[CirruData]): seq[CirruData] =
  var noSpread = true
  for x in xs:
    if x.kind == crDataSymbol and x.symbolVal == "&" and not x.dynamic:
      noSpread = false
      break
  if noSpread:
    return xs

  var args: seq[CirruData]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      if x.isList.not:
        raiseEvalError("Spread mode expects a list", xs)
      for y in x:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&" and not x.dynamic:
      spreadMode = true
    else:
      args.add x
  args

proc spreadFuncArgs*(xs: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): seq[CirruData] =
  var noSpread = true
  for x in xs:
    if x.kind == crDataSymbol and x.symbolVal == "&" and not x.dynamic:
      noSpread = false
      break
  if noSpread:
    var args = newSeq[CirruData](xs.len)
    for idx, x in xs:
      args[idx] = interpret(x, scope, ns)
    return args

  var args: seq[CirruData] = @[]
  var spreadMode = false
  for x in xs:
    if spreadMode:
      let ys = interpret(x, scope, ns)
      if not ys.isList:
        raiseEvalError("Spread mode expects a list", xs)
      for y in ys.listVal:
        args.add y
      spreadMode = false
    elif x.isSymbol and x.symbolVal == "&" and not x.dynamic:
      spreadMode = true
    else:
      args.add interpret(x, scope, ns)
  args

proc getKwd*(x: CirruEdnValue, k: string): CirruEdnValue =
  if x.kind != crEdnMap:
    raise newException(ValueError, "getKwd expects a map")
  x.get(genCrEdnKeyword(k))

proc containsKwd*(x: CirruEdnValue, k: string): bool =
  if x.kind != crEdnMap:
    raise newException(ValueError, "containsKwd expects a map")
  x.contains(genCrEdnKeyword(k))
