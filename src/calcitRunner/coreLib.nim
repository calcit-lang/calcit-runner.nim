
import tables
import json

import ./types
import ./data
import ./helpers

let coreNs* = "calcit.core"

proc coreFnError(msg: string, x: CirruData = CirruData(kind: crDataNil)) =
  raise newException(ValueError, msg)

proc nativeAdd(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native add")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for adding", a)
  if b.kind != crDataNumber: coreFnError("Required number for adding", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal + b.numberVal)

proc nativeMinus(args: seq[CirruData], interpret: EdnEvalFn, scope: CirruDataScope): CirruData =
  if args.len != 2: coreFnError("Expected 2 arguments in native minus")
  let a = args[0]
  let b = args[1]
  if a.kind != crDataNumber: coreFnError("Required number for minus", a)
  if b.kind != crDataNumber: coreFnError("Required number for minus", b)
  return CirruData(kind: crDataNumber, numberVal: a.numberVal - b.numberVal)

# TODO &and
# TODO &or
# TODO not

# TODO empty?
# TODO first
# TODO rest


# injecting functions to calcit.core directly
proc loadCoreDefs*(programData: var Table[string, ProgramFile], interpret: EdnEvalFn): void =
  var coreFile: ProgramFile
  let rootScope = CirruDataScope()

  coreFile.defs["&+"] = CirruData(kind: crDataFn, fnVal: nativeAdd)
  coreFile.defs["&-"] = CirruData(kind: crDataFn, fnVal: nativeMinus)

  let codeOfAdd2 = (%* ["defn", "&+2", ["x"], ["&+", "x", "2"]]).toCirruCode(coreNs)
  coreFile.defs["&+2"] = interpret(codeOfAdd2, rootScope)

  programData[coreNs] = coreFile
