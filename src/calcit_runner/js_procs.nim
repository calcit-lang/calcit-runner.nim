
import math
import sets
import tables
import sequtils
import strutils

import ternary_tree

import dual_balanced_ternary

import ./types
import ./errors
import ./data

# TODO staled feature: compiling to js. prefer using src/includes/calcit.procs.ts
# Nim supports js backend, however, Nim is a low-level language.
# some libs used in Nim does not fit js, this CLI has this problem.
# just in theory, compile those functions to `calcit.procs.js`,
# and code emitted from `emit_js.nim` could run.

proc initCrString(x: cstring): CirruData {.exportc.} =
  CirruData(kind: crDataString, stringVal: $x)

proc initCrKeyword(x: cstring): CirruData {.exportc.} =
  CirruData(kind: crDataKeyword, keywordVal: $x)

proc initCrNumber(x: float): CirruData {.exportc.} =
  CirruData(kind: crDataNumber, numberVal: x)

proc initCrBool(x: bool): CirruData {.exportc.} =
  CirruData(kind: crDataBool, boolVal: x)

proc initCrNil(): CirruData {.exportc.} =
  CirruData(kind: crDataNil)

proc createList(xs: varargs[CirruData]): CirruData {.exportc: "_LIST_".} =
  var ys: seq[CirruData]
  for x in xs:
    ys.add x
  CirruData(kind: crDataList, listVal: initTernaryTreeList(ys))

proc nativeMap(xs: varargs[CirruData]): CirruData {.exportc: "_AND_MAP_".} =
  var value = initTable[CirruData, CirruData]()
  for pair in xs:
    if pair.kind != crDataList:
      raiseEvalError("Map requires nested children pairs", pair)
    if pair.len() != 2:
      raiseEvalError("Each pair of table contains 2 elements", pair)
    value[pair[0]] = pair[1]
  return CirruData(kind: crDataMap, mapVal: initTernaryTreeMap(value))

proc nativePrint(args: varargs[CirruData]): CirruData {.exportc: "print"} =
  echo args.map(`$`).join(" ")
  return CirruData(kind: crDataNil)

proc nativeCount(a: CirruData): CirruData {.exportc: "count".} =
  case a.kind
  of crDataNil:
    return CirruData(kind: crDataNumber, numberVal: 0.0)
  of crDataList:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  of crDataMap:
    return CirruData(kind: crDataNumber, numberVal: a.len.float)
  of crDataSet:
    return CirruData(kind: crDataNumber, numberVal: a.setVal.len.float)
  of crDataString:
    return CirruData(kind: crDataNumber, numberVal: a.stringVal.len.float)
  else:
    raiseEvalError("Cannot count data", a)

proc nativeDivide(a, b: CirruData): CirruData {.exportc: "_SLSH_".} =
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal / b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for divide", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for divide", b)
  if b.numberVal == 0.0: raiseEvalError("Cannot divide by 0", @[a, b])
  return CirruData(kind: crDataNumber, numberVal: a.numberVal / b.numberVal)
