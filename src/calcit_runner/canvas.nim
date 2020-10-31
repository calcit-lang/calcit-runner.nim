
import json_paint

import ./types
import ./errors

proc nativeInitCanvas*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  initCanvas("title", 400, 400)
  return CirruData(kind: crDataBool, boolVal: true)

proc nativeDrawCanvas*(args: seq[CirruData], interpret: FnInterpret, scope: CirruDataScope): CirruData =
  if args.len != 1: raiseEvalError("Expects 1 argument", args)

  let data = args[0]

  if data.kind == crDataBool:
    renderCanvas(data.boolVal)
  else:
    echo "WARNING: expects a bool"

  return CirruData(kind: crDataBool, boolVal: true)
