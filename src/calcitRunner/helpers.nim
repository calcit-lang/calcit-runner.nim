
import cirruParser
import terminal

import ./types

proc raiseEvalError*(msg: string, code: CirruData): void =
  var e: CirruEvalError
  new e
  e.msg = msg
  e.code = code

  raise e

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

proc coreFnError*(msg: string, x: CirruData = CirruData(kind: crDataNil)) =
  var e: CirruCoreError
  new e
  e.msg = msg
  e.data = x

  raise e
