
import terminal

import cirru_parser
import ternary_tree

import ./types

type CirruEvalError* = ref object of ValueError
  code*: CirruData

proc raiseEvalError*(msg: string, code: CirruData): void =
  var e: CirruEvalError
  new e
  e.msg = msg
  e.code = code

  raise e

proc raiseEvalError*(msg: string, xs: seq[CirruData]): void =
  let code = CirruData(kind: crDataList, listVal: initTernaryTreeList(xs))
  raiseEvalError(msg, code)

proc coloredEcho*(color: ForegroundColor, text: varargs[string]): void =
  var buffer = ""
  for x in text:
    buffer = buffer & x
  setForegroundColor(color)
  echo buffer
  resetAttributes()

proc dimEcho*(text: varargs[string]): void =
  var buffer = ""
  for x in text:
    buffer = buffer & x
  # setForegroundColor(0x555555)
  setStyle({styleDim})
  echo buffer
  resetAttributes()
