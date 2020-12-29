
import math
import sets
import sequtils
import strutils

import ternary_tree

import dual_balanced_ternary

import ./types
import ./errors
import ./data

# TODO staled feature: compiling to js
# Nim supports js backend, however, Nim is a low-level language.
# some libs used in Nim does not fit js, this CLI has this problem.
# just in theory, compile those functions to `calcit.procs.js`,
# and code emitted from `emit_js.nim` could run.

proc nativePrint(args: seq[CirruData]): CirruData {.exportc: "print".} =
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
