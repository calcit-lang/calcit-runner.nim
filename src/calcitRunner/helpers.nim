
import cirruParser
import terminal

import ./types

proc raiseInterpretException*(msg: string, line, column: int) =
  var e: CirruInterpretError
  new e
  e.msg = msg
  e.line = line
  e.column = column
  raise e

proc raiseInterpretExceptionAtNode*(msg: string, node: CirruNode) =
  raiseInterpretException(msg, node.line, node.column)

proc coloredEcho*(color: ForegroundColor, text: varargs[string]): void =
  var buffer = ""
  for x in text:
    buffer = buffer & x
  setForegroundColor(color)
  echo buffer
  resetAttributes()

