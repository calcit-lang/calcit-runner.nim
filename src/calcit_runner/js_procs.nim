
import math
import ternary_tree

import dual_balanced_ternary

import ./types
import ./errors

proc count*(args: seq[CirruData]): int {.exportc.} =
  return 1

proc nativeDivide(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope, ns: string): CirruData {.exportc.} =
  if args.len != 2: raiseEvalError("Expected 2 arguments in native divide", args)
  let a = args[0]
  let b = args[1]
  if a.kind == crDataTernary and b.kind == crDataTernary:
    return CirruData(kind: crDataTernary, ternaryVal: a.ternaryVal / b.ternaryVal)
  if a.kind != crDataNumber: raiseEvalError("Required number for divide", a)
  if b.kind != crDataNumber: raiseEvalError("Required number for divide", b)
  if b.numberVal == 0.0: raiseEvalError("Cannot divide by 0", args)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal / b.numberVal)
